import base64
import copy
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
published = importlib.import_module('test_published_examples')
followup = importlib.import_module('create_release_followup')
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

    def test_published_validation_never_bundles_or_rewrites(self):
        before = {p: p.read_bytes() for p in (self.root / 'examples').glob('*.roc')}
        with patch.object(local, 'ROOT', self.root), patch.object(local, 'bundle_package') as bundle, \
             patch.object(local, 'copy_examples_with_bundle_url') as rewrite, \
             patch.object(local, 'run_example_checks') as checks, patch.object(local, 'run_example_tests'), \
             patch.object(local, 'run_example_apps'), patch.object(local, 'build_and_run_examples'):
            published.main()
        bundle.assert_not_called()
        rewrite.assert_not_called()
        self.assertEqual(checks.call_args.args[0], sorted(before))
        self.assertEqual(before, {p: p.read_bytes() for p in before})

    def test_published_urls_reject_local_floating_mixed_or_missing_dependencies(self):
        target = self.root / 'examples/animals.roc'
        for url in ['http://127.0.0.1:8000/test.tar.zst', 'https://example.com/package',
                    URL.replace('0.13.0', 'latest'), URL.replace('0.13.0', '0.12.0')]:
            target.write_text(f'ansi: "{url}"\n')
            with self.subTest(url=url), self.assertRaises(ValueError):
                published.published_examples(self.root)
        target.write_text('no dependency\n')
        with self.assertRaises(ValueError): published.published_examples(self.root)

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


class FollowupTests(unittest.TestCase):
    def setUp(self):
        self.commit = {'commit': {'verification': {'verified': True}},
                       'author': {'login': 'github-actions[bot]'},
                       'parents': [{'sha': 'base'}],
                       'files': [{'filename': 'examples/animals.roc', 'sha': 'blob', 'status': 'modified'}]}
        self.blobs = {'examples/animals.roc': 'blob'}

    def test_existing_signed_commit_can_be_reused(self):
        followup.verify_commit(self.commit, 'base', self.blobs)

    def test_unsigned_foreign_or_modified_branch_cannot_be_overwritten(self):
        for keys, value in [(['commit', 'verification', 'verified'], False),
                            (['author', 'login'], 'human'), (['parents', 0, 'sha'], 'other'),
                            (['files', 0, 'sha'], 'different'), (['files', 0, 'filename'], 'package/main.roc')]:
            commit = copy.deepcopy(self.commit)
            target = commit
            for key in keys[:-1]: target = target[key]
            target[keys[-1]] = value
            with self.subTest(keys=keys), self.assertRaises(ValueError):
                followup.verify_commit(commit, 'base', self.blobs)

    def test_followup_includes_example_urls_but_excludes_docs_and_source_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def git(*args):
                return subprocess.run(['git', *args], cwd=root, capture_output=True, check=True)
            git('init')
            for directory in ['examples', 'www', 'package']:
                (root / directory).mkdir()
                (root / directory / 'file.txt').write_text('old')
            git('add', '.')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'fixture')
            (root / 'examples/file.txt').write_text('new URL')
            (root / 'www/file.txt').unlink()
            (root / 'www/new.html').write_text('new docs')
            (root / 'package/file.txt').write_text('source edit')
            with patch.object(followup, 'ROOT', root):
                changes, blobs = followup.changes()
            self.assertEqual(set(blobs), {'examples/file.txt'})
            self.assertEqual(changes['deletions'], [])
            self.assertEqual(base64.b64decode(changes['additions'][0]['contents']), b'new URL')

    def test_new_followup_uses_signed_api_commit_and_checks_signature_before_pr(self):
        env = {'GITHUB_REPOSITORY': 'owner/project', 'RELEASE_VERSION': '0.13.0',
               'GITHUB_REF_NAME': 'main', 'GITHUB_SHA': 'base'}
        responses = [[], {}, {'data': {'createCommitOnBranch': {'commit': {'oid': 'signed'}}}},
                     self.commit, [], {'html_url': 'https://github.com/owner/project/pull/1'}]
        with patch.dict(os.environ, env), patch.object(followup, 'run', return_value='base\n'), \
             patch.object(followup, 'changes', return_value=({'additions': [], 'deletions': []}, self.blobs)), \
             patch.object(followup, 'api', side_effect=responses) as api:
            followup.main()
        request = api.call_args_list[2].args[1]['variables']['input']
        self.assertEqual(request['expectedHeadOid'], 'base')
        self.assertEqual(api.call_args_list[3].args[0], 'repos/owner/project/commits/signed')
        self.assertEqual(api.call_args_list[-1].args[1]['base'], 'main')


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
