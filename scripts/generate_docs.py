#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def normalize_version(value: str) -> str:
    normalized = value.removeprefix("v")
    if not VERSION_RE.fullmatch(normalized):
        raise ValueError("version must use x.y.z format, for example 0.12.0")
    return normalized


def redirect_page(version: str) -> str:
    target = f"/roc-ansi/{version}/"
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url={target}">
  <link rel="canonical" href="{target}">
  <title>Redirecting to {version}</title>
</head>
<body>
  <p><a href="{target}">Redirecting to {version}</a></p>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate versioned roc-ansi documentation.")
    parser.add_argument("version", nargs="?", default=os.environ.get("DOCS_VERSION"))
    parser.add_argument("--docs-root", type=Path, default=Path(os.environ.get("DOCS_ROOT", "www")))
    parser.add_argument("--skip-index", action="store_true")
    args = parser.parse_args()

    if args.version is None:
        parser.error("VERSION is required (or set DOCS_VERSION)")
    try:
        version = normalize_version(args.version)
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    docs_root = args.docs_root if args.docs_root.is_absolute() else ROOT / args.docs_root
    docs_root = docs_root.resolve()
    output_dir = docs_root / version
    if output_dir.exists():
        if output_dir.is_dir():
            shutil.rmtree(output_dir)
        else:
            output_dir.unlink()
    docs_root.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        [os.environ.get("ROC", "roc"), "docs", "package/main.roc", f"--output={output_dir}"],
        cwd=ROOT,
        check=True,
    )
    if not args.skip_index:
        (docs_root / "index.html").write_text(redirect_page(version), encoding="utf-8")

    print(f"Generated docs for {version} in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
