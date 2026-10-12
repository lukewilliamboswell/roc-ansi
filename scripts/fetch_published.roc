#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Published
import src/Script

## Download the examples archive of a release, exactly as published.
##
##     scripts/fetch_published.roc
##     RELEASE_TAG=0.13.2 OUTPUT_DIR=/tmp/published scripts/fetch_published.roc
##
## Fetches the latest release's archive, or that of the release `RELEASE_TAG`
## names, into `dist/published` or the directory named by `OUTPUT_DIR`. Needs
## `gh` to be authenticated.
##
## In a workflow it reports the release as `tag` and the file as `archive`.
## Before anything has been released both are empty, which is not a failure.
main! = |_args| {
	directory = Path.utf8(Script.env_or!("OUTPUT_DIR", "dist/published")?)
	tag = match Script.env_or!("RELEASE_TAG", "")? {
		"" => Published.latest_tag!()?
		named => named
	}
	archive = if tag == "" {
		Script.info!("NOTICE", "nothing has been released yet, so there is nothing to test")?
		""
	} else {
		Path.display(Published.download_examples!(tag, directory)?)
	}
	match Script.env_or!("GITHUB_OUTPUT", "")? {
		"" => {}
		outputs => {
			file = Path.utf8(outputs)
			earlier = if Path.is_file!(file)? Path.read_utf8!(file)? else ""
			Path.write_utf8!(file, "${earlier}tag=${tag}\narchive=${archive}\n")?
		}
	}
	Script.info!("FETCHED", if archive == "" "nothing" else "${archive} of release ${tag}")
}
