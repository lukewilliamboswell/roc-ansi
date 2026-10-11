import cli.Env
import cli.OsStr
import cli.Path
import Files
import Release
import Script
import Text

## API documentation stored as a release asset and restored for the site.
##
## Generated documentation is never committed. Each release attaches an
## archive of its docs, and the site is assembled from those archives.
DocsArchive := [].{

	## Pack the generated docs in `docs_root/<version>` into `output_dir`,
	## returning the archive. Packing the same files twice gives the same
	## bytes, so a retried release can tell its asset is already published.
	pack! = |docs_root, version, output_dir| {
		if !Release.valid_docs_version(version) {
			return Script.fail!("not a documentation version: ${version}")
		}
		source = Path.join(docs_root, version)
		Script.require_file!(Path.join(source, "index.html"))?
		Path.create_all!(output_dir)?
		output = Path.absolute!(output_dir)?
		archive = Path.join(output, Release.docs_archive(version))
		tarball = Path.join(output, "${Release.docs_archive(version).drop_suffix(".gz")}")

		# Regular files only, in byte order, so the archive does not depend on
		# how the filesystem lists them. A symbolic link is an error.
		root_prefix = "${Path.display(docs_root)}/"
		entries = Text.sort(Files.all_files!(source)?.map(|path| Path.display(path).drop_prefix(root_prefix)))
		_ = Script.command("tar").capture!(
			[
				"--create",
				"--file",
				Path.to_os_str(tarball),
				"--format=ustar",
				"--mtime=@0",
				"--owner=0",
				"--group=0",
				"--numeric-owner",
				"--mode=0644",
				"--no-recursion",
				"--directory",
				Path.to_os_str(docs_root),
				"--verbatim-files-from",
				"--files-from=-",
			],
			".",
			Str.to_utf8(Str.join_with(entries, "\n")),
		)?
		# -n leaves the tarball's name and timestamp out of the gzip header.
		_ = Script.command("gzip").capture!(["-n", "-f", Path.to_os_str(tarball)], ".", [])?
		Script.info!("ARCHIVE", Path.display(archive))?
		Ok(archive)
	}

	## Unpack the docs of `version` from `archive` into `output/<version>`,
	## which must not exist. Every entry is checked before anything is written,
	## so an archive cannot write outside that directory or create links.
	restore! = |archive, version, output| {
		if !Release.valid_docs_version(version) {
			return Script.fail!("not a documentation version: ${version}")
		}
		tar = Script.command("tar")
		entries = Text.lines(tar.capture_utf8!(["-tzf", Path.to_os_str(archive)], ".")?)
		# The verbose listing starts each line with the entry type: `-` is a
		# regular file and `d` a directory.
		kinds = Text.lines(tar.capture_utf8!(["-tvzf", Path.to_os_str(archive)], ".")?)
		if kinds.len() != entries.len() or kinds.any(|kind| !kind.starts_with("-") and !kind.starts_with("d")) {
			return Script.fail!("the documentation archive must hold only regular files and directories")
		}
		match entries.keep_if(|entry| !Release.valid_docs_entry(version, entry)) {
			[] => {}
			[entry, ..] => return Script.fail!("unsafe entry in the documentation archive: ${entry}")
		}
		if !entries.contains("${version}/index.html") {
			return Script.fail!("the documentation archive lacks ${version}/index.html")
		}
		destination = Path.join(output, version)
		if Path.exists!(destination)? {
			return Script.fail!("documentation destination already exists: ${Path.display(destination)}")
		}

		# Unpack beside the destination, then move the finished tree into place.
		Path.create_all!(output)?
		stage = Env.create_temp_dir_in!(output, "docs-restore-")?
		_ = tar.capture!(["-xzf", Path.to_os_str(archive), "--no-same-owner", "--no-same-permissions", "-C", Path.to_os_str(stage)], ".", [])?
		Path.rename!(Path.join(stage, version), destination)?
		Path.delete_all!(stage)
	}

	## Restore the docs of every published release that attached them into
	## `output`. Needs `gh` to be authenticated, for example through `GH_TOKEN`.
	fetch! = |output| {
		gh = Script.command("gh")
		# One JSON object per line: every published release with its assets.
		query = ".[] | select((.draft or .prerelease) | not) | {tag: .tag_name, assets: [.assets[] | {name: .name, url: .browser_download_url, digest: (.digest // \"\")}]}"
		listing = gh.capture_utf8!(["api", "--paginate", "repos/${Release.repository}/releases?per_page=100", "--jq", query], ".")?
		for line in Text.lines(listing) {
			release : { tag : Str, assets : List({ name : Str, url : Str, digest : Str }) }
			release = Json.parse(line).map_err(|_| UnreadableReleaseListing(line))?
			restore_release!(gh, release, output)?
		}
		Ok({})
	}
}

restore_release! = |gh, release, output| {
	version = release.tag
	asset_name = Release.docs_archive(version)
	if !Release.valid_docs_version(version) {
		return Ok({})
	}
	asset = match release.assets.keep_if(|candidate| candidate.name == asset_name) {
		# Releases before 0.8.0 never attached documentation.
		[] => return Ok({})
		[one] => one
		_ => return Script.fail!("release ${version} has several documentation archives")
	}
	if asset.url != "https://github.com/${Release.repository}/releases/download/${version}/${asset_name}" {
		return Script.fail!("unexpected documentation asset URL: ${asset.url}")
	}
	Env.with_temp_dir!(
		|temporary| {
			_ = gh.capture!(["release", "download", OsStr.from_str(version), "--repo", OsStr.from_str(Release.repository), "--pattern", OsStr.from_str(asset_name), "--dir", Path.to_os_str(temporary)], ".", [])?
			archive = Path.join(temporary, asset_name)
			if asset.digest != "" and asset.digest != "sha256:${sha256!(archive)?}" {
				return Script.fail!("documentation digest mismatch for ${version}")
			}
			DocsArchive.restore!(archive, version, output)
		},
	)?
	Script.info!("RESTORED", "release documentation for ${version}")
}

sha256! = |path| {
	report = Script.command("sha256sum").capture_utf8!([Path.to_os_str(path)], ".")?
	match Str.split_first(report, " ") {
		Ok({ before, .. }) => Ok(before)
		Err(_) => Err(UnreadableDigest(report))
	}
}
