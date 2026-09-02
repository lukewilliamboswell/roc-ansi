#!/usr/bin/env python3
from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ROC = os.environ.get("ROC", "roc")


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def section(title: str) -> None:
    print(f"\n{title}", flush=True)


def main() -> None:
    tmp_base = Path(os.environ.get("ROC_ANSI_TMPDIR", ROOT / ".roc-ansi-tmp")).resolve()
    os.environ["ROC_ANSI_TMPDIR"] = str(tmp_base)
    os.environ["ROC"] = ROC

    tmp_dir = tmp_base / "roc-ansi-ci"
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    docs_dir = tmp_dir / "docs"
    bundle_dir = tmp_dir / "bundle"
    docs_dir.mkdir(parents=True)
    bundle_dir.mkdir(parents=True)

    run([ROC, "version"])
    section("Checking format...")
    run([ROC, "fmt", "--check", "package", "examples"])
    section("Checking package...")
    run([ROC, "check", "package/main.roc"])
    section("Running package tests...")
    run([ROC, "test", "package/main.roc"])
    section("Generating package docs...")
    run([ROC, "docs", "package/main.roc", f"--output={docs_dir}"])

    if platform.system() == "Windows":
        section("Skipping package bundling on Windows.")
        return

    section("Bundling package...")
    run([sys.executable, "scripts/bundle.py", "--output-dir", str(bundle_dir)])
    section("Testing examples against localhost bundle...")
    run([sys.executable, "scripts/test_bundle_examples.py"])


if __name__ == "__main__":
    main()
