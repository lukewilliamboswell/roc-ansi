#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import cli.Path
import src/Preview
import src/Script
import src/Site

## Assemble the GitHub Pages site and preview it locally.
##
##     scripts/serve_site.roc
##     SITE_PORT=8000 FETCH_RELEASE_DOCS=1 scripts/serve_site.roc
##
## Takes the same `SITE_OUTPUT` and `FETCH_RELEASE_DOCS` as `build_site.roc`,
## and serves on a free port unless `SITE_PORT` names one.
main! = |_args| {
	roc_nightly = Script.roc_nightly!()?
	output = Path.absolute!(Path.utf8(Script.env_or!("SITE_OUTPUT", ".roc-ansi-tmp/site")?))?
	releases = match Script.env_or!("FETCH_RELEASE_DOCS", "")? {
		"" | "0" => SkipReleaseDocs
		_ => FetchReleaseDocs
	}
	requested = Script.env_or!("SITE_PORT", "0")?
	port = match U16.from_str(requested) {
		Ok(value) => value
		Err(_) => return Script.fail!("SITE_PORT must be between 0 and 65535, not ${requested}")
	}
	Site.assemble!(roc_nightly, output, releases)?
	Preview.serve!(output, port)
}
