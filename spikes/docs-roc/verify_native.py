#!/usr/bin/env python3
"""Acceptance checks for the real manual through the released utility.

Test tooling only: rendering and publication do not require Python.
"""
import argparse
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.ids = []
        self.links = []
        self.images = []
        self.codes = []
        self.code = None
        self.list_depth = 0
        self.max_list_depth = 0
        self.tables = 0
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])
        if tag == 'img':
            self.images.append(attrs['src'])
        if tag == 'code':
            self.code = []
        if tag == 'ul':
            self.list_depth += 1
            self.max_list_depth = max(self.max_list_depth, self.list_depth)
        if tag == 'table':
            self.tables += 1

    def handle_endtag(self, tag):
        if tag == 'code' and self.code is not None:
            self.codes.append(''.join(self.code))
            self.code = None
        if tag == 'ul':
            self.list_depth -= 1

    def handle_data(self, text):
        if self.code is not None:
            self.code.append(text)


def sources(path, active=()):
    assert path not in active, f'Include cycle: {path}'
    text = path.read_text()
    return re.sub(r'^include::([^\[]+)\[[^\]]*\]$',
                  lambda m: sources(path.parent / m[1], (*active, path)),
                  text, flags=re.M)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--backend', choices=['roc', 'legacy'], default='roc')
    args = parser.parse_args()
    site = (args.output / 'site').resolve()
    pages = {path.resolve(): Page(path) for path in site.glob('*.html')}
    expected = {path.with_suffix('.html').name for path in Path('docs').glob('*.adoc')}
    assert expected <= {path.name for path in pages}, 'Missing chapter route'
    index = pages[site / 'index.html']
    legacy_anchor_gaps = []
    for path, page in pages.items():
        assert len(page.ids) == len(set(page.ids)), f'Duplicate IDs in {path}'
        for link in page.links + page.images:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            target = (path.parent / unquote(url.path)).resolve() if url.path else path
            assert target.is_relative_to(site), f'Link escapes site: {link}'
            assert target.exists(), f'Missing target in {path.name}: {link}'
            if url.fragment and target.suffix == '.html':
                target_page = pages.get(target) or Page(target)
                if unquote(url.fragment) not in target_page.ids:
                    if args.backend == 'legacy':
                        legacy_anchor_gaps.append(f'{path.name}: {link}')
                    else:
                        raise AssertionError(f'Missing anchor: {link}')
    source = sources(Path('docs/index.adoc'))
    blocks = re.findall(r'^\[source[^\n]*\]\n----\n(.*?)\n----', source, re.M | re.S)
    # Both renderers preserve original code; allow the final LF used by <pre>.
    rendered = Counter(block.rstrip('\n') for block in index.codes)
    for code, count in Counter(blocks).items():
        assert rendered[code] >= count, f'Lost/changed code: {code[:80]!r}'
    assert index.tables == 6, f'Expected six manual tables, got {index.tables}'
    assert len(index.images) == 5, 'Expected five original screenshots'
    assert index.max_list_depth >= 2, 'Contents/list hierarchy was flattened'
    for name in ['what-roc-ansi-is', 'get-started', 'learn-from-the-examples',
                 'contribute', 'maintain-and-release', 'release-notes']:
        assert name in index.ids, f'Missing stable chapter anchor: {name}'
    assert (site / 'main' / 'ANSI' / 'index.html').is_file(), 'Current API reference missing'
    pdf = args.output / 'roc-ansi.pdf'
    assert pdf.read_bytes().startswith(b'%PDF-'), 'Invalid/missing PDF'
    assert pdf.read_bytes() == (site / pdf.name).read_bytes(), 'PDF download differs'
    if args.backend == 'roc':
        info = subprocess.check_output(['pdfinfo', str(pdf)], text=True)
        assert re.search(r'^Tagged:\s+yes$', info, re.M), 'PDF reader reports untagged output'
        text = subprocess.check_output(['pdftotext', str(pdf), '-'], text=True)
        for heading in ['What roc-ansi is', 'Get started', 'Learn from the examples',
                        'Contribute', 'Maintain and release', 'Release notes']:
            assert heading in text, f'PDF text missing chapter: {heading}'
        assert (site / '_roc-docs' / 'fonts').is_dir(), 'Embedded web fonts missing'
    if legacy_anchor_gaps:
        print('BASELINE EXISTING ANCHOR GAPS (native must resolve these):')
        for gap in legacy_anchor_gaps:
            print(f'  {gap}')
    print(f'PASS {len(expected)} manual routes; stable combined-manual anchors and local files; '
          f'{len(blocks)} exact code blocks; six tables; five screenshots; API; PDF '
          f'({pdf.stat().st_size:,} bytes); backend={args.backend}')


if __name__ == '__main__':
    main()
