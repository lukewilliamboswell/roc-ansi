#!/usr/bin/env python3
"""Generate site pages that pair terminal captures with their Roc source."""
from __future__ import annotations
import argparse
import html
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = "https://github.com/lukewilliamboswell/roc-ansi"
EXAMPLES = {
    "animals": ("Animals", "A short sentence composed from independently colored terminal fragments."),
    "colors": ("Colors", "ANSI 16-color, 256-color, and RGB foreground and background combinations."),
    "styles": ("Styles", "Bold, faint, italic, strike-through, underline, invert, and combined styles."),
    "tui-menu": ("TUI menu", "A compact interactive-menu treatment using color and emphasis."),
    "text-editor": ("Text editor", "A terminal text-editing example backed by the package's piece table."),
}

def document(title: str, body: str, *, root: str = "../") -> str:
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · roc-ansi</title>
<link rel="icon" type="image/svg+xml" href="{root}favicon.svg">
<link rel="stylesheet" href="{root}vendor/simple-css/simple.min.css"><link rel="stylesheet" href="{root}site.css"><link rel="stylesheet" href="{root}roc-highlight.css">
</head><body><header><nav>
<a class="brand" href="{root}">roc-ansi</a>
<a href="{root}main/">API docs</a>
<a href="{root}examples/">Examples</a>
<a href="{REPO}">GitHub</a>
<a href="{REPO}/releases">Releases</a>
</nav></header>
<main>{body}</main><footer>roc-ansi is open source under the UPL-1.0 license.</footer>
<script type="module" src="{root}roc-highlight.js"></script></body></html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path)
    site = parser.parse_args().site.resolve()
    output = site / "examples"
    assets = output / "assets"
    assets.mkdir(parents=True, exist_ok=True)
    cards: list[str] = []
    for slug, (title, description) in EXAMPLES.items():
        source_path = ROOT / "examples" / f"{slug}.roc"
        media_path = ROOT / "examples" / f"{slug}.gif"
        if not media_path.is_file():
            media_path = ROOT / "examples" / f"{slug}.png"
        if not source_path.is_file() or not media_path.is_file():
            raise SystemExit(f"Missing source or terminal capture for {slug}")
        shutil.copy2(media_path, assets / media_path.name)
        source = html.escape(source_path.read_text(encoding="utf-8"))
        body = f'<p><a href="../">← All examples</a></p><h1>{html.escape(title)}</h1><p>{html.escape(description)}</p>'
        body += f'<figure class="terminal-capture"><img src="../assets/{media_path.name}" alt="{html.escape(title)} rendered in a terminal"><figcaption>Terminal output</figcaption></figure>'
        body += f'<h2>Source</h2><pre><code class="language-roc">{source}</code></pre>'
        page_dir = output / slug
        page_dir.mkdir(exist_ok=True)
        (page_dir / "index.html").write_text(document(title, body, root="../../"), encoding="utf-8")
        cards.append(f'<article><a href="./{slug}/"><img src="./assets/{media_path.name}" alt="{html.escape(title)} terminal output"></a><h2><a href="./{slug}/">{html.escape(title)}</a></h2><p>{html.escape(description)}</p></article>')
    gallery = '<h1>Examples</h1><p>See each program rendered in a terminal alongside its complete Roc source.</p><div class="example-grid">' + "".join(cards) + "</div>"
    (output / "index.html").write_text(document("Examples", gallery), encoding="utf-8")
    print(f"Generated {len(EXAMPLES)} example pages in {output}")

if __name__ == "__main__":
    main()
