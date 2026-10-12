#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.OsStr
import src/Examples
import src/Script

## Run every example against the working tree and compare what it prints
## with the cases recorded in `tests/spec.json`.
##
##     scripts/test_examples.roc
##     scripts/test_examples.roc -- --update
##
## `--update` rewrites the recorded output from what the examples print now,
## so an intended change in an example arrives as a diff to review.
main! = |args| {
	mode = match args.map(OsStr.display) {
		[] => Compare
		["--update"] => Update
		_ => return Script.fail!("usage: scripts/test_examples.roc [-- --update]")
	}
	Examples.run!(Script.roc!()?, { directory: "examples", source: Direct, spec: "tests/spec.json", mode, roc_args: [] })
}
