import cli.OsStr
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
		wanted = if tag == "" [] else [OsStr.from_str(tag)]
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
}
