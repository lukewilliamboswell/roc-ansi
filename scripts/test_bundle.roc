#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Bundle
import src/Script

## Test the examples against one package bundle, served from a loopback address.
##
##     scripts/test_bundle.roc
##     BUNDLE_PATH=dist/<hash>.tar.zst scripts/test_bundle.roc
##
## Tests the only bundle in `dist` unless `BUNDLE_PATH` names one. The release
## workflow passes the exact archive it is about to publish, which catches
## packaging mistakes that checking the source tree cannot.
main! = |_args| {
	roc = Script.roc!()?
	bundle = Bundle.selected!("dist")?
	Bundle.test!(roc, bundle)
}
