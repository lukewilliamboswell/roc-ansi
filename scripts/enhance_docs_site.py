#!/usr/bin/env python3
"""Brand the generated API documentation and add the vendored Roc highlighter."""
from __future__ import annotations
import argparse
import os
import re
from pathlib import Path

PACKAGE_NAME = "roc-ansi"
DOCS_FOOTER = (
    "<footer><p>"
    '<a href="{root}">roc-ansi</a> is open source under the UPL-1.0 license.'
    "</p></footer>"
)
DOCS_INTRO = """
        <h1 class="pkg-full-name-heading">roc-ansi</h1>
        <p>Typed helpers for ANSI terminal control sequences in Roc: colors, text
        styles, cursor and screen control, input parsing, and simple layouts.</p>
        <p>Pick a module from the sidebar, or head back to the
        <a href="{root}">roc-ansi site</a> for
        <a href="{root}examples/">rendered examples</a>.</p>
"""


def relative(site: Path, page: Path, name: str = "") -> str:
    path = os.path.relpath(site / name, page.parent).replace(os.sep, "/")
    return path if name else f"{path}/"


def enhance(site: Path, page: Path) -> bool:
    document = original = page.read_text(encoding="utf-8")
    if "</head>" not in document or "</body>" not in document:
        raise ValueError(f"cannot enhance {page}: incomplete HTML document")
    root = relative(site, page)

    generated_docs = 'id="sidebar-nav"' in document
    for asset in ("roc-highlight.css", "docs-site.css"):
        if asset == "docs-site.css" and not generated_docs:
            continue
        if asset not in document:
            stylesheet = relative(site, page, asset)
            document = document.replace("</head>", f'    <link rel="stylesheet" href="{stylesheet}">\n</head>', 1)
    if "roc-highlight.js" not in document:
        script = relative(site, page, "roc-highlight.js")
        document = document.replace("</body>", f'    <script type="module" src="{script}"></script>\n</body>', 1)

    # `roc docs` names the package after its directory (`package/main.roc`).
    if "<title>package Docs</title>" in document:
        document = document.replace("<title>package Docs</title>", f"<title>{PACKAGE_NAME} API documentation</title>", 1)
    else:
        document = re.sub(r"<title>(\w+) Docs</title>", rf"<title>\g<1> · {PACKAGE_NAME}</title>", document, count=1)
    document = re.sub(
        r'(<h1 class="pkg-full-name"><a href=")([^"]*)(">)package(</a></h1>)',
        lambda match: f'{match.group(1)}{match.group(2) or "."}{match.group(3)}{PACKAGE_NAME}{match.group(4)}',
        document,
        count=1,
    )
    # Give the docs a way back to the rest of the site.
    # The sidebar grid expects exactly two rows, so the link goes inside the module list.
    document = document.replace(
        '<ul class="module-links">',
        '<ul class="module-links">\n'
        f'                <li class="sidebar-entry sidebar-site-link"><a href="{root}">← roc-ansi site</a></li>',
        1,
    )
    document = re.sub(
        r"<footer><p>Made by people who like to make nice things\.</p></footer>",
        DOCS_FOOTER.format(root=root),
        document,
        count=1,
    )
    # The package has no doc comment, so the docs landing page is otherwise empty.
    if 'class="docs-index"' in document:
        document = re.sub(
            r'(<div class="main-content">\s*<!--!.{0,4}?-->)',
            lambda match: match.group(1) + DOCS_INTRO.format(root=root),
            document,
            count=1,
            flags=re.S,
        )

    if document == original:
        return False
    page.write_text(document, encoding="utf-8")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path)
    site = parser.parse_args().site.resolve()
    for asset in ("roc-highlight.js", "roc-highlight.css", "docs-site.css"):
        if not (site / asset).is_file():
            raise SystemExit(f"Missing highlighter asset: {site / asset}")
    changed = sum(enhance(site, page) for page in site.rglob("*.html"))
    print(f"Enhanced {changed} generated documentation pages")


if __name__ == "__main__":
    main()
