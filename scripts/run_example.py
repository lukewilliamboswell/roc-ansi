#!/usr/bin/env python3
"""Run an example against a fresh localhost bundle of the working-tree package."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

from test_bundle_examples import ROC, local_examples


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("example", help="Example name or path, e.g. animals or examples/animals.roc")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="Arguments passed to the example")
    args = parser.parse_args()
    name = Path(args.example).stem + ".roc"
    with local_examples() as (examples, _):
        selected = next((example for example in examples if example.name == name), None)
        if selected is None or name == "tests.roc":
            parser.error("Choose a runnable example; use all_tests.py for package and example tests")
        command = [ROC, selected.name, "--no-cache"]
        if args.args:
            command.extend(args.args if args.args[0] == "--" else ["--", *args.args])
        # Inherit the terminal for interactive examples, and retain the server
        # until the example exits. Only its temporary copy has a localhost URL.
        subprocess.run(command, cwd=selected.parent, check=True)


if __name__ == "__main__":
    main()
