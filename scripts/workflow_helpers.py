#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


def append_output(path: Path, name: str, value: str) -> None:
    if any(character in name + value for character in "\r\n"):
        raise ValueError("GitHub output names and values must be single-line")
    with path.open("a", encoding="utf-8") as output:
        output.write(f"{name}={value}\n")


def roc_version(path: Path = ROOT / ".roc-version") -> str:
    value = path.read_text(encoding="utf-8").strip()
    if not value or any(character in value for character in "\r\n"):
        raise ValueError(f"{path} must contain one non-empty Roc version")
    return value


def bundle_url(metadata: Path, repository: str, version: str) -> str:
    if not REPOSITORY_RE.fullmatch(repository):
        raise ValueError(f"invalid GitHub repository: {repository!r}")
    if not version or any(character in version for character in "\r\n/"):
        raise ValueError(f"invalid release version: {version!r}")

    bundles = json.loads(metadata.read_text(encoding="utf-8"))
    if not isinstance(bundles, list) or len(bundles) != 1:
        count = len(bundles) if isinstance(bundles, list) else "non-list"
        raise ValueError(f"expected exactly one release bundle, found {count}")
    artifact = bundles[0].get("artifact_file") if isinstance(bundles[0], dict) else None
    if not isinstance(artifact, str) or Path(artifact).name != artifact or any(c in artifact for c in "\r\n#?"):
        raise ValueError("release bundle has an invalid artifact_file")
    return f"https://github.com/{repository}/releases/download/{version}/{artifact}"


def validate_examples() -> None:
    roc = os.environ.get("ROC", "roc")
    examples = sorted((ROOT / "examples").glob("*.roc"))
    if not examples:
        raise ValueError("no Roc examples found")
    for example in examples:
        subprocess.run([roc, "check", str(example), "--no-cache"], cwd=ROOT, check=True)
    subprocess.run([roc, "test", "examples/tests.roc", "--no-cache"], cwd=ROOT, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    version_parser = commands.add_parser("roc-version")
    version_parser.add_argument("--github-output", type=Path, required=True)
    url_parser = commands.add_parser("bundle-url")
    url_parser.add_argument("--metadata", type=Path, required=True)
    url_parser.add_argument("--repository", required=True)
    url_parser.add_argument("--version", required=True)
    url_parser.add_argument("--github-output", type=Path, required=True)
    commands.add_parser("validate-examples")
    args = parser.parse_args()

    try:
        if args.command == "roc-version":
            append_output(args.github_output, "nightly-tag", roc_version())
        elif args.command == "bundle-url":
            append_output(
                args.github_output,
                "bundle-url",
                bundle_url(args.metadata, args.repository, args.version),
            )
        elif args.command == "validate-examples":
            validate_examples()
    except (json.JSONDecodeError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
