#!/usr/bin/env python3
"""Test the immutable release URLs checked into examples, without rewriting them."""
from __future__ import annotations

import os
from pathlib import Path
import re
import tempfile

import test_bundle_examples as examples


RELEASE_URL = re.compile(
    r"https://github\.com/lukewilliamboswell/roc-ansi/releases/download/"
    r"\d+\.\d+\.\d+/[A-Za-z0-9]+\.tar\.zst"
)


def published_examples(root: Path) -> list[Path]:
    paths = sorted((root / "examples").glob("*.roc"))
    if not paths:
        raise ValueError("No published examples found")
    urls = set()
    for path in paths:
        urls_in_file = re.findall(r'(?m)^\s*ansi:\s*"([^"]+)"', path.read_text())
        if len(urls_in_file) != 1 or not RELEASE_URL.fullmatch(urls_in_file[0]):
            raise ValueError(f"{path.name} must pin one published roc-ansi release bundle")
        urls.add(urls_in_file[0])
    if len(urls) != 1:
        raise ValueError("All examples must refer to the same published roc-ansi release")
    print(f"Testing checked-in published package: {next(iter(urls))}", flush=True)
    return paths


def main() -> None:
    paths = published_examples(examples.ROOT)
    tmp_parent = Path(os.environ.get("ROC_ANSI_TMPDIR", examples.ROOT / ".roc-ansi-tmp"))
    tmp_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="published-examples-", dir=tmp_parent) as tmp:
        examples.run_example_checks(paths)
        examples.run_example_tests(paths)
        examples.run_example_apps(paths)
        examples.build_and_run_examples(paths, Path(tmp) / "build")


if __name__ == "__main__":
    main()
