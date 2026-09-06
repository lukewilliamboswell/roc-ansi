#!/usr/bin/env python3
"""Copy example terminal captures into the site and build the landing-page grid."""
from __future__ import annotations
import argparse
import html
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_URL = "https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples"
PLACEHOLDER = "<!--EXAMPLES-->"
EXAMPLES = {
    "animals": "Animals",
    "colors": "Colors",
    "styles": "Styles",
    "tui-menu": "TUI menu",
    "text-editor": "Text editor",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path)
    site = parser.parse_args().site.resolve()
    assets = site / "examples"
    assets.mkdir(parents=True, exist_ok=True)

    cards: list[str] = []
    for slug, title in EXAMPLES.items():
        source_path = ROOT / "examples" / f"{slug}.roc"
        media_path = ROOT / "examples" / f"{slug}.png"
        if not source_path.is_file() or not media_path.is_file():
            raise SystemExit(f"Missing source or terminal capture for {slug}")
        shutil.copy2(media_path, assets / media_path.name)
        label = html.escape(title)
        cards.append(
            f'<a class="example" href="{SOURCE_URL}/{slug}.roc">'
            f'<img src="./examples/{media_path.name}" alt="{label} rendered in a terminal" loading="lazy">'
            f"<span>{label}</span></a>"
        )

    index = site / "index.html"
    document = index.read_text(encoding="utf-8")
    if PLACEHOLDER not in document:
        raise SystemExit(f"{index} is missing {PLACEHOLDER}")
    grid = '<div class="example-grid">' + "".join(cards) + "</div>"
    index.write_text(document.replace(PLACEHOLDER, grid, 1), encoding="utf-8")
    print(f"Added {len(EXAMPLES)} examples to the landing page")


if __name__ == "__main__":
    main()
