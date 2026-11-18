import cli.OsStr
import cli.Path
import Release
import Script
import Text

## What GitHub says this repository has released.
Published := [].{

	## The tag and asset names of a release: the one tagged `tag`, or the
	## latest when `tag` is "". "Latest" never means a draft or a prerelease.
	## Needs `gh` to be authenticated, for example through `GH_TOKEN`.
	release! : Str => Try({ tag : Str, assets : List(Str) }, _)
	release! = |tag| {
		wanted = if (tag == "") [] else [OsStr.from_str(tag)]
		# Without a tag, gh selects the latest published release.
		listing = Script.command("gh").capture_utf8!(
			["release", "view"].concat(wanted).concat(["--repo", OsStr.from_str(Release.repository), "--json", "tagName,assets", "--jq", "{tag: .tagName, assets: [.assets[].name]}"]),
			".",
		)?
		found : Try({ tag : Str, assets : List(Str) }, _)
		found = Json.parse(listing)
		found.map_err(|_| UnreadableReleaseListing(listing))
	}

	## The versions whose API documentation is on the site: every published
	## release that attached a documentation archive.
	documented! : () => Try(List(Str), _)
	documented! = || {
		# One JSON object per line: every published release with its asset names.
		query = ".[] | select((.draft or .prerelease) | not) | {tag: .tag_name, assets: [.assets[].name]}"
		listing = Script.command("gh").capture_utf8!(["api", "--paginate", "repos/${Release.repository}/releases?per_page=100", "--jq", query], ".")?
		releases = Text.lines(listing).map_try(
			|line| {
				release : Try({ tag : Str, assets : List(Str) }, _)
				release = Json.parse(line)
				release.map_err(|_| UnreadableReleaseListing(line))
			},
		)?
		Ok(releases.keep_if(|release| Release.valid_docs_version(release.tag) and Release.find_docs_archive(release.tag, release.assets) != Missing).map(|release| release.tag))
	}

	## The tag of the latest release, or "" when nothing has been released
	## yet. A draft or a prerelease is never the latest.
	latest_tag! : () => Try(Str, _)
	latest_tag! = || {
		listed = Script.command("gh").capture_utf8!(["release", "list", "--repo", OsStr.from_str(Release.repository), "--limit", "100", "--json", "tagName,isLatest", "--jq", "[.[] | select(.isLatest)][0].tagName // \"\""], ".")?
		Ok(listed.trim())
	}

	## Download the examples archive of the release tagged `tag` into
	## `directory`, exactly as published, and return where it is.
	download_examples! : Str, Path => Try(Path, _)
	download_examples! = |tag, directory| {
		release = Published.release!(tag)?
		asset = match Release.find_examples_archive(release.tag, release.assets) {
			Zip(name) => name
			Missing => return Script.fail!("release ${release.tag} has no examples archive attached")
		}
		Path.create_all!(directory)?
		Script.command("gh").run!(["release", "download", OsStr.from_str(release.tag), "--repo", OsStr.from_str(Release.repository), "--pattern", OsStr.from_str(asset), "--dir", Path.to_os_str(directory)])?
		Ok(Path.join(directory, asset))
	}
}
