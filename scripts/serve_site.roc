#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Html
import src/Preview
import src/Script
import src/Site

## Add the API reference to the documentation site and preview it locally.
##
##     scripts/serve_site.roc
##     SITE_PORT=8000 FETCH_RELEASE_DOCS=1 scripts/serve_site.roc
##
## Takes the same `SITE_OUTPUT` and `FETCH_RELEASE_DOCS` as `build_site.roc`,
## and serves on a free port unless `SITE_PORT` names one. The manual is
## previewed too when it has been rendered there first; docs/contributing.adoc
## says how.
main! = |_args| {
	roc = Script.roc!()?
	output = Path.absolute!(Path.utf8(Script.env_or!("SITE_OUTPUT", ".docs-out/site")?))?
	releases = match Script.env_or!("FETCH_RELEASE_DOCS", "")? {
		"" | "0" => SkipReleaseDocs
		_ => FetchReleaseDocs
	}
	requested = Script.env_or!("SITE_PORT", "0")?
	port = match U16.from_str(requested) {
		Ok(value) => value
		Err(_) => return Script.fail!("SITE_PORT must be between 0 and 65535, not ${requested}")
	}
	Site.assemble!(roc, output, releases)?
	if !Path.is_file!(Path.join(output, "index.html"))? {
		Script.info!("NOTE", "the manual has not been rendered into ${Path.display(output)}, so only the API reference is served: open ${Html.base_path}/main/")?
	}
	Preview.serve!(output, port)
}
