import importlib
import json
import io
import tarfile
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.request import urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
local = importlib.import_module('test_bundle_examples')
published = importlib.import_module('published_examples')
docs = importlib.import_module('generate_docs')
release_docs = importlib.import_module('release_docs')

URL = 'https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.0/Abc123.tar.zst'


class ExampleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'examples').mkdir()
        for name in ['animals.roc', 'tests.roc']:
            (self.root / 'examples' / name).write_text(f'app [main!] {{\n ansi: "{URL}",\n}}\n')

    def test_generated_docs_are_not_tracked(self):
        tracked = subprocess.run(['git', 'ls-files', 'www'], cwd=Path(__file__).resolve().parents[1],
                                 capture_output=True, text=True, check=True).stdout.splitlines()
        import re
        self.assertFalse([name for name in tracked if re.match(r'www/(?:main|[0-9]+\.[0-9]+\.[0-9]+)/', name)])

    def test_pack_rewrites_only_the_archived_copies_to_the_release_bundle(self):
        relative = 'app [main!] {\n ansi: "../package/main.roc",\n roc: "nightly-x",\n}\n'
        for name in ['animals.roc', 'tests.roc']:
            (self.root / 'examples' / name).write_text(relative)
        before = {p: p.read_bytes() for p in (self.root / 'examples').glob('*.roc')}
        with patch.object(published, 'ROOT', self.root):
            archive = published.pack('0.13.0', URL, self.root / 'out')
            self.assertEqual(archive.name, 'roc-ansi-examples-0.13.0.tar.gz')
            paths = published.extract(archive, self.root / 'extracted')
            self.assertEqual([p.name for p in paths], ['animals.roc', 'tests.roc'])
            self.assertIn(f'ansi: "{URL}"', paths[0].read_text())
            self.assertEqual(before, {p: p.read_bytes() for p in before})
            with self.assertRaises(ValueError):
                published.pack('0.13.0', 'http://127.0.0.1:8000/x.tar.zst', self.root / 'bad')

    def test_extract_rejects_local_floating_mixed_missing_and_unexpected_entries(self):
        def build(files):
            archive = self.root / 'a.tar.gz'
            with tarfile.open(archive, 'w:gz') as tar:
                for name, text in files.items():
                    member = tarfile.TarInfo(name)
                    member.size = len(text.encode())
                    tar.addfile(member, io.BytesIO(text.encode()))
            return archive
        ok = f'ansi: "{URL}"\n'
        cases = [{'examples/a.roc': 'ansi: "../package/main.roc"\n'},
                 {'examples/a.roc': f'ansi: "{URL.replace("0.13.0", "latest")}"\n'},
                 {'examples/a.roc': 'no dependency\n'},
                 {'examples/a.roc': ok, 'examples/b.roc': ok.replace('0.13.0', '0.12.0')},
                 {'examples/a.roc': ok, '../escape.roc': ok}, {'examples/a.txt': ok}]
        for index, files in enumerate(cases):
            with self.subTest(case=index), self.assertRaises(ValueError):
                published.extract(build(files), self.root / f'x{index}')

    def test_compiler_selection_changes_only_the_roc_pin(self):
        path = self.root / 'examples/animals.roc'
        path.write_text(f'app [main!] {{\n ansi: "{URL}",\n roc: "old",\n}}\n')
        published.select_compiler([path], 'nightly-new')
        self.assertEqual(path.read_text(), f'app [main!] {{\n ansi: "{URL}",\n roc: "nightly-new",\n}}\n')

    def test_local_bundle_is_served_and_only_temporary_copies_are_rewritten(self):
        archive = self.root / 'Abc123.tar.zst'
        archive.write_bytes(b'local package changes')
        before = (self.root / 'examples/animals.roc').read_bytes()
        with patch.object(local, 'ROOT', self.root), patch.dict(os.environ, ROC_ANSI_TMPDIR=str(self.root / 'tmp')):
            with local.local_examples(archive) as (paths, _):
                self.assertNotEqual(paths[0].parent, self.root / 'examples')
                source = paths[0].read_text()
                url = source.split('ansi: "')[1].split('"')[0]
                self.assertTrue(url.startswith('http://127.0.0.1:'))
                with urlopen(url) as response:
                    self.assertEqual(response.read(), archive.read_bytes())
                self.assertEqual((self.root / 'examples/animals.roc').read_bytes(), before)
            self.assertFalse(paths[0].exists())

    def test_docs_generation_preserves_landing_page_and_other_releases(self):
        root = self.root / 'www'
        root.mkdir()
        landing = root / 'index.html'
        landing.write_text('<!--EXAMPLES--> <!--VERSIONS-->')
        (root / '0.12.0').mkdir()
        (root / '0.12.0/index.html').write_text('archive')
        with patch.object(sys, 'argv', ['generate_docs.py', '0.13.0', '--docs-root', str(root)]), \
             patch.object(docs.subprocess, 'run'):
            self.assertEqual(docs.main(), 0)
        self.assertEqual(landing.read_text(), '<!--EXAMPLES--> <!--VERSIONS-->')
        self.assertEqual((root / '0.12.0/index.html').read_text(), 'archive')


class ReleaseDocsTests(unittest.TestCase):
    def test_pack_is_reproducible_and_restore_preserves_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'source/0.13.0'
            (source / 'ANSI').mkdir(parents=True)
            (source / 'index.html').write_text('release docs')
            (source / 'ANSI/index.html').write_text('module docs')
            first = release_docs.pack(root / 'source', '0.13.0', root / 'first')
            second = release_docs.pack(root / 'source', '0.13.0', root / 'second')
            self.assertEqual(first.read_bytes(), second.read_bytes())
            release_docs.restore(first, '0.13.0', root / 'site')
            self.assertEqual((root / 'site/0.13.0/ANSI/index.html').read_text(), 'module docs')
            with self.assertRaises(ValueError):
                release_docs.restore(first, '0.13.0', root / 'site')

    def test_restore_rejects_traversal_and_links_before_writing(self):
        for name, kind in [('../escape', tarfile.REGTYPE), ('/escape', tarfile.REGTYPE),
                           ('0.13.0/../../escape', tarfile.REGTYPE),
                           ('0.13.0/link', tarfile.SYMTYPE), ('0.12.0/index.html', tarfile.REGTYPE)]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                archive = root / 'bad.tar.gz'
                with tarfile.open(archive, 'w:gz') as output:
                    member = tarfile.TarInfo(name)
                    member.type = kind
                    member.linkname = '../escape'
                    output.addfile(member, io.BytesIO(b''))
                with self.assertRaises(ValueError):
                    release_docs.restore(archive, '0.13.0', root / 'site')
                self.assertFalse((root / 'site').exists())

    def test_publish_refuses_to_replace_different_existing_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / release_docs.asset_name('0.13.0')
            archive.write_bytes(b'new')
            existing = {'assets': [{'name': archive.name, 'digest': 'sha256:other'}]}
            with patch.object(release_docs, 'github', return_value=existing), \
                 patch.object(release_docs.subprocess, 'run') as run:
                with self.assertRaises(ValueError): release_docs.publish(archive, '0.13.0')
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
