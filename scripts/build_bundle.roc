#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Bundle
import src/Script

## Bundle the working-tree package for a release.
##
##     scripts/build_bundle.roc
##
## Writes the archive to `dist`, or to the directory named by `OUTPUT_DIR`.
main! = |_args| {
	# The bundle holds the package being developed, so the floating compiler
	# builds it. The tooling compiler only runs this script.
	roc = Script.roc!()?
	output_dir = Script.env_or!("OUTPUT_DIR", "dist")?
	_ = Bundle.build!(roc, Path.utf8(output_dir))?
	Ok({})
}
