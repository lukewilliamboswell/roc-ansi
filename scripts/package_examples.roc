#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Archive
import src/Bundle
import src/Script

## Build the examples archive attached to a release.
##
##     RELEASE_VERSION=0.14.0 scripts/package_examples.roc
##
## Writes `roc-ansi-examples-<version>.zip` to `dist`, or to the directory named
## by `OUTPUT_DIR`. The archived copies depend on the release URL of the only
## bundle in that directory, or of the one `BUNDLE_PATH` names. The examples in
## the repository are not changed.
main! = |_args| {
	version = Script.env!("RELEASE_VERSION")?
	output_dir = Path.utf8(Script.env_or!("OUTPUT_DIR", "dist")?)
	bundle = Bundle.selected!(output_dir)?
	Script.require_file!(bundle)?
	_ = Archive.pack!(version, Script.file_name(bundle)?, output_dir)?
	Ok({})
}
