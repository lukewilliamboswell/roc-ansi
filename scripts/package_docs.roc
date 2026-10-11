#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import cli.Env
import cli.Path
import src/DocsArchive
import src/Script
import src/Site

## Generate the API documentation of a release and pack it as a release asset.
##
##     DOCS_VERSION=0.14.0 scripts/package_docs.roc
##
## Writes `roc-ansi-docs-<version>.tar.gz` to `dist`, or to the directory named
## by `OUTPUT_DIR`. The site restores archived docs from these assets.
main! = |_args| {
	roc_nightly = Script.roc_nightly!()?
	version = Script.env!("DOCS_VERSION")?.drop_prefix("v")
	output_dir = Path.utf8(Script.env_or!("OUTPUT_DIR", "dist")?)
	Env.with_temp_dir!(
		|docs_root| {
			Site.docs!(roc_nightly, Path.join(docs_root, version))?
			_ = DocsArchive.pack!(docs_root, version, output_dir)?
			Ok({})
		},
	)
}
