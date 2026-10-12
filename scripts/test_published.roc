#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Env
import cli.OsStr
import cli.Path
import src/Archive
import src/Examples
import src/Release
import src/Script

## Test the examples archive of the latest release, exactly as published.
##
##     scripts/test_published.roc
##     EXAMPLES_ARCHIVE=dist/roc-ansi-examples-0.14.0.zip scripts/test_published.roc
##
## This answers whether the release people download today works with today's
## compiler. Nothing is pointed at the working tree: the archived examples
## fetch the published bundle and are compared with the output archived
## beside them. A release published before archives carried that is only
## required to build and exit cleanly. `EXAMPLES_ARCHIVE` names a local archive to test
## instead, which the release workflow uses before attaching one.
main! = |_args| {
	roc = Script.roc!()?
	Env.with_temp_dir!(
		|temporary| {
			archive = match Script.env_or!("EXAMPLES_ARCHIVE", "")? {
				"" => download_latest!(Path.join(temporary, "download"))?
				local => Path.utf8(local)
			}
			unpacked = Archive.unpack!(archive, Path.join(temporary, "unpacked"))?
			Script.info!("PUBLISHED", "${Release.name} ${unpacked.version}: ${unpacked.url}")?
			roc.run!(["version"])?
			# An empty package cache makes Roc fetch the published bundle, as it
			# would for someone using this release for the first time.
			fetching = roc.with_empty_package_cache(Path.join(temporary, "cache"))
			Examples.run!(fetching, { directory: unpacked.examples, source: Direct, expected: unpacked.expected, mode: Compare, roc_args: [] })
		},
	)
}

download_latest! = |directory| {
	gh = Script.command("gh")
	repository = OsStr.from_str(Release.repository)
	# Without a tag, gh selects the latest published release.
	listing = gh.capture_utf8!(["release", "view", "--repo", repository, "--json", "tagName,assets", "--jq", "{tag: .tagName, assets: [.assets[].name]}"], ".")?
	release : { tag : Str, assets : List(Str) }
	release = Json.parse(listing).map_err(|_| UnreadableReleaseListing(listing))?
	asset = match Release.find_examples_archive(release.tag, release.assets) {
		Zip(name) => name
		LegacyTarball(name) => {
			Script.info!("NOTE", "release ${release.tag} attached its examples as a tarball; later releases attach a zip")?
			name
		}
		Missing => return Script.fail!("release ${release.tag} has no examples archive attached")
	}
	Path.create_all!(directory)?
	gh.run!(["release", "download", OsStr.from_str(release.tag), "--repo", repository, "--pattern", OsStr.from_str(asset), "--dir", Path.to_os_str(directory)])?
	Ok(Path.join(directory, asset))
}
