import cli.OsStr
import Release
import Script

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
}
