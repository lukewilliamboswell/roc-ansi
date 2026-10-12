#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Archive
import src/Bundle
import src/Script

## Test an examples archive, unchanged, against the bundle it names.
##
##     scripts/test_bundle.roc
##     BUNDLE_PATH=dist/<hash>.tar.zst EXAMPLES_ARCHIVE=dist/roc-ansi-examples-0.14.0.zip scripts/test_bundle.roc
##
## Tests the only bundle and the only examples archive in `dist` unless
## `BUNDLE_PATH` and `EXAMPLES_ARCHIVE` name them. The release workflow passes
## the exact files it is about to publish, which catches packaging mistakes
## that checking the source tree cannot.
main! = |_args| {
	roc = Script.roc!()?
	bundle = Bundle.selected!("dist")?
	archive = Archive.selected!("dist")?
	Bundle.test!(roc, bundle, archive)
}
