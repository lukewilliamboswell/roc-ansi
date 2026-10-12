#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Bundle
import src/Notes
import src/Release
import src/Script

## Render a release's notes as the body of its GitHub release.
##
##     RELEASE_VERSION=0.14.0 scripts/render_release_notes.roc
##
## Reads `docs/releases/<version>.adoc`, fills in the URL of the bundle in
## `dist`, or the one `BUNDLE_PATH` names, and adds the compilers the release
## was built and tested with. Writes Markdown to `.release/release-notes.md`,
## or to the file named by `OUTPUT`.
##
## A dry run has no notes of its own, so it renders the newest notes there
## are: a mistake in them then fails on the pull request that makes it.
main! = |_args| {
	version = Script.env!("RELEASE_VERSION")?
	output = Path.utf8(Script.env_or!("OUTPUT", ".release/release-notes.md")?)
	noted = if version == Release.dry_run_version newest_notes!()? else version
	source_path = Path.utf8(Release.notes_file(noted))
	if !Path.is_file!(source_path)? {
		return Script.fail!("${Path.display(source_path)} does not exist: write the notes for ${version} and merge them before releasing it")
	}
	url = match Release.bundle_url(version, Script.file_name(Bundle.selected!("dist")?)?) {
		Ok(value) => value
		Err(_) => return Script.fail!("${version} and the bundle in dist do not name a release bundle")
	}
	body = match Notes.render(Path.read_utf8!(source_path)?, { title: "= ${Release.name} ${noted}", package_url: url }) {
		Ok(rendered) => rendered
		Err(WrongTitle(found)) => return Script.fail!("${Path.display(source_path)} must open with \"= ${Release.name} ${noted}\", not \"${found}\"")
		Err(UnusedPlaceholder) => return Script.fail!("${Path.display(source_path)} never uses ${Notes.placeholder}, so it does not say how to install the release")
		Err(UnresolvedPlaceholder(name)) => return Script.fail!("${Path.display(source_path)} uses ${name}, which this release has no URL for")
		Err(UnclosedBlock) => return Script.fail!("${Path.display(source_path)} opens a ---- block that it never closes")
	}
	compilers = Notes.compilers({ roc: compiler!(Script.roc!()?)?, roc_stable: compiler!(Script.roc_stable!()?)? })
	match Str.split_last(Path.display(output), "/") {
		Ok({ before, .. }) => Path.create_all!(Path.utf8(before))?
		Err(_) => {}
	}
	Path.write_utf8!(output, "${body}\n${compilers}")?
	Script.info!("NOTES", "${Path.display(output)} from ${Path.display(source_path)}")
}

compiler! = |command| Ok(command.capture_utf8!(["version"], ".")?.trim().drop_prefix("Roc compiler version "))

newest_notes! = || {
	names = Path.list!("docs/releases")?.map_try(Script.file_name)?
	match Release.newest_first(names.keep_if(|name| name.ends_with(".adoc")).map(|name| name.drop_suffix(".adoc")).keep_if(Release.valid_version)) {
		[newest, ..] => Ok(newest)
		[] => Script.fail!("docs/releases holds no release notes")
	}
}
