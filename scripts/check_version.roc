#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.OsStr
import cli.Path
import src/Published
import src/Release
import src/Script

## Check that a version may be released: its notes are written, and it moves
## far enough from the latest release for what changed in the package's API.
##
##     RELEASE_VERSION=0.14.0 scripts/check_version.roc
##
## `roc bump` compares the package with the latest release's bundle and fails
## when the version understates the change, so a breaking change cannot go out
## as a patch. Needs `gh` to be authenticated.
##
## A dry run has no version to hold to that: it reports the bump the change
## needs, and a comparison that cannot be made is not an error there.
main! = |_args| {
	version = Script.env!("RELEASE_VERSION")?
	dry_run = version == Release.dry_run_version
	if !Release.publishable_version(version) {
		return Script.fail!("${version} is not a version that can be released")
	}
	if !dry_run and !Path.is_file!(Path.utf8(Release.notes_file(version)))? {
		return Script.fail!("${Release.notes_file(version)} does not exist: write the notes for ${version} and merge them before releasing it")
	}

	latest = Published.release!("")?
	previous = match latest.assets.keep_if(Release.valid_bundle_file) {
		[bundle_file] =>
			match Release.bundle_url(latest.tag, bundle_file) {
				Ok(url) => url
				Err(_) => return Script.fail!("release ${latest.tag} is not a version roc bump can compare with")
			}
		_ => return Script.fail!("release ${latest.tag} does not have exactly one bundle attached")
	}
	roc = Script.roc!()?
	compare = ["bump", "--old", OsStr.from_str(previous)]
	if dry_run {
		match roc.run!(compare.append("package/main.roc")) {
			Ok({}) => Ok({})
			Err(_) => Script.info!("NOTE", "roc bump could not compare with ${latest.tag}; a release would stop here")
		}
	} else {
		roc.run!(compare.concat(["--expect", OsStr.from_str(Release.base_version(version)), "package/main.roc"]))
	}
}
