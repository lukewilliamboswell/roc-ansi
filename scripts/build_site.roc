#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Script
import src/Site

## Add the API reference to the documentation site.
##
##     scripts/build_site.roc
##     FETCH_RELEASE_DOCS=1 SITE_OUTPUT=pages-site scripts/build_site.roc
##
## Works on `.docs-out/site`, where the build-docs action renders the manual,
## or on the directory named by `SITE_OUTPUT`. With `FETCH_RELEASE_DOCS=1` the
## archived docs of every release are restored from its assets, which needs
## `gh` to be authenticated.
main! = |_args| {
	roc = Script.roc!()?
	output = Path.absolute!(Path.utf8(Script.env_or!("SITE_OUTPUT", ".docs-out/site")?))?
	releases = match Script.env_or!("FETCH_RELEASE_DOCS", "")? {
		"" | "0" => SkipReleaseDocs
		_ => FetchReleaseDocs
	}
	Site.assemble!(roc, output, releases)
}
