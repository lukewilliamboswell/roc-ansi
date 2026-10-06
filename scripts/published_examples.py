#!/usr/bin/env python3
"""Pack and test the examples archive attached to each roc-ansi release.

Examples in the repository use a relative path to the current package source. A release
attaches a frozen copy whose application headers point at that release's immutable
bundle URL. Compiler validation tests the latest frozen copy with only its compiler pin
replaced, so the check shows whether a compiler works with what users download.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

import test_bundle_examples as examples


ROOT = examples.ROOT
REPOSITORY = "lukewilliamboswell/roc-ansi"
RELEASE_URL = re.compile(
    rf"https://github\.com/{re.escape(REPOSITORY)}/releases/download/"
    r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?/[A-Za-z0-9]+\.tar\.zst"
)
ARCHIVE_NAME = re.compile(r"roc-ansi-examples-(\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\.tar\.gz")
ROC_PIN_RE = re.compile(r'(?m)^(\s*roc:\s*)"[^"]+"')


def archive_name(version: str) -> str:
    return f"roc-ansi-examples-{version}.tar.gz"


def pack(version: str, bundle_url: str, output_dir: Path) -> Path:
    """Write the frozen examples archive for a release, rewriting only the staged copies."""
    if not RELEASE_URL.fullmatch(bundle_url):
        raise ValueError(f"Not an immutable roc-ansi release bundle URL: {bundle_url}")
    sources = sorted((ROOT / "examples").glob("*.roc"))
    if not sources:
        raise ValueError("No examples found")
    output_dir.mkdir(parents=True, exist_ok=True)
    archive = output_dir / archive_name(version)
    with tarfile.open(archive, "w:gz") as tar:
        for source in sources:
            text = source.read_text(encoding="utf-8")
            rewritten, count = examples.PACKAGE_DEPENDENCY_RE.subn(
                lambda match: f'{match.group(1)}"{bundle_url}"', text, count=1
            )
            if count != 1:
                raise ValueError(f"{source.name} does not declare the ansi dependency")
            data = rewritten.encode("utf-8")
            info = tarfile.TarInfo(f"examples/{source.name}")
            info.size, info.mtime, info.mode = len(data), 0, 0o644
            tar.addfile(info, fileobj=io.BytesIO(data))
    print(f"Created: {archive}")
    return archive


def extract(archive: Path, destination: Path) -> list[Path]:
    """Extract only flat example files and require one immutable roc-ansi release per archive."""
    with tarfile.open(archive, "r:gz") as tar:
        members = tar.getmembers()
        for member in members:
            parts = Path(member.name).parts
            if not member.isfile() or len(parts) != 2 or parts[0] != "examples" or not parts[1].endswith(".roc"):
                raise ValueError(f"Unexpected archive member: {member.name}")
        tar.extractall(destination, members=members, filter="data")
    paths = sorted((destination / "examples").glob("*.roc"))
    if not paths:
        raise ValueError("Examples archive contains no examples")
    urls = set()
    for path in paths:
        found = re.findall(r'(?m)^\s*ansi:\s*"([^"]+)"', path.read_text(encoding="utf-8"))
        if len(found) != 1 or not RELEASE_URL.fullmatch(found[0]):
            raise ValueError(f"{path.name} must pin one published roc-ansi release bundle")
        urls.update(found)
    if len(urls) != 1:
        raise ValueError("All published examples must use the same roc-ansi release bundle")
    print(f"Testing published package: {next(iter(urls))}", flush=True)
    return paths


def select_compiler(paths: list[Path], pin: str) -> None:
    """Replace only the application compiler pin in the temporary copies."""
    for path in paths:
        text = path.read_text(encoding="utf-8")
        rewritten, count = ROC_PIN_RE.subn(lambda match: f'{match.group(1)}"{pin}"', text, count=1)
        if count != 1:
            raise ValueError(f"{path.name} does not declare a roc compiler pin")
        path.write_text(rewritten, encoding="utf-8")


def current_pin() -> str:
    text = (ROOT / "package/main.roc").read_text(encoding="utf-8")
    match = ROC_PIN_RE.search(text)
    if match is None:
        raise ValueError("package/main.roc does not declare a roc compiler pin")
    return re.search(r'"([^"]+)"', match.group(0)).group(1)


def download_latest(destination: Path) -> Path | None:
    """Download the examples archive of the latest release, or None if it has none."""
    release = json.loads(subprocess.run(
        ["gh", "release", "view", "--repo", REPOSITORY, "--json", "tagName,assets"],
        text=True, capture_output=True, check=True,
    ).stdout)
    assets = [asset["name"] for asset in release["assets"] if ARCHIVE_NAME.fullmatch(asset["name"])]
    if not assets:
        return None
    if len(assets) != 1 or ARCHIVE_NAME.fullmatch(assets[0]).group(1) != release["tagName"]:
        raise ValueError(f"Unexpected examples archive assets on {release['tagName']}: {assets}")
    subprocess.run(
        ["gh", "release", "download", release["tagName"], "--repo", REPOSITORY,
         "--pattern", assets[0], "--dir", str(destination), "--clobber"],
        check=True,
    )
    return destination / assets[0]


def test(archive: Path | None) -> None:
    tmp_parent = Path(os.environ.get("ROC_ANSI_TMPDIR", ROOT / ".roc-ansi-tmp"))
    tmp_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="published-examples-", dir=tmp_parent) as tmp:
        tmp_dir = Path(tmp)
        if archive is None:
            archive = download_latest(tmp_dir)
            if archive is None:
                print("::notice::The latest release has no examples archive yet; "
                      "skipping the published-example lane until one is published.")
                return
        paths = extract(archive, tmp_dir / "published")
        select_compiler(paths, current_pin())
        examples.run_example_checks(paths)
        examples.run_example_tests(paths)
        examples.run_example_apps(paths)
        examples.build_and_run_examples(paths, tmp_dir / "build")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    pack_parser = commands.add_parser("pack", help="create the examples archive for a release")
    pack_parser.add_argument("--version", required=True)
    pack_parser.add_argument("--bundle-url", required=True)
    pack_parser.add_argument("--output-dir", type=Path, default=ROOT / ".roc-ansi-tmp" / "examples-assets")
    test_parser = commands.add_parser("test", help="test a published examples archive with the pinned compiler")
    test_parser.add_argument("--archive", type=Path, help="test this archive instead of the latest release's")
    args = parser.parse_args()
    if args.command == "pack":
        pack(args.version, args.bundle_url, args.output_dir)
    else:
        test(args.archive)


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        sys.exit(str(error))
