#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Env
import cli.Path
import src/Archive
import src/Examples
import src/Published
import src/Release
import src/Script

## Test the examples archive of a release, exactly as published.
##
##     scripts/test_published.roc
##     RELEASE_TAG=0.13.2 scripts/test_published.roc
##     EXAMPLES_ARCHIVE=dist/roc-ansi-examples-0.14.0.zip scripts/test_published.roc
##
## This answers whether the release people download today works with today's
## compiler. Nothing is pointed at the working tree: the archived examples
## fetch the published bundle and are compared with the output archived
## beside them.
##
## Tests the latest release, or the one `RELEASE_TAG` names. `EXAMPLES_ARCHIVE`
## names an archive that has already been downloaded, which is how the nightly
## workflow keeps a failed download apart from a failed example.
main! = |_args| {
	roc = Script.roc!()?
	Env.with_temp_dir!(
		|temporary| {
			archive = match Script.env_or!("EXAMPLES_ARCHIVE", "")? {
				"" => Published.download_examples!(Script.env_or!("RELEASE_TAG", "")?, Path.join(temporary, "download"))?
				local => Path.utf8(local)
			}
			unpacked = Archive.unpack!(archive, Path.join(temporary, "unpacked"))?
			Script.info!("PUBLISHED", "${Release.name} ${unpacked.version}: ${unpacked.url}")?
			roc.run!(["version"])?
			# An empty package cache makes Roc fetch the published bundle, as it
			# would for someone using this release for the first time.
			fetching = roc.with_empty_package_cache(Path.join(temporary, "cache"))
			Examples.run!(fetching, { directory: unpacked.examples, source: Direct, spec: unpacked.spec, mode: Compare, roc_args: [] })
		},
	)
}
