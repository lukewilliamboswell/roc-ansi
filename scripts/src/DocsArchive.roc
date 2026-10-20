import cli.Cmd
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
		if !Release.valid_version(version) {
			return Script.fail!("not a release version: ${version}")
		}
		source = Path.join(docs_root, version)
		Script.require_file!(Path.join(source, "index.html"))?
		Path.create_all!(output_dir)?
		output = Path.absolute!(output_dir)?
		archive = Path.join(output, Release.docs_archive(version))
		# zip adds to an existing archive, which would keep entries from an earlier run.
		if Path.exists!(archive)? {
			Path.delete!(archive)?
		}

		# Regular files only, in byte order, so the archive does not depend on
		# how the filesystem lists them. A symbolic link is an error.
		root_prefix = "${Path.display(docs_root)}/"
		entries = Text.sort(Files.all_files!(source)?.map(|path| Path.display(path).drop_prefix(root_prefix)))
		Env.with_temp_dir!(
			|stage| {
				# A zip records each file's time and mode, so pack copies that
				# all carry the same ones: the earliest time a zip can hold.
				Path.copy_dir!(source, Path.join(stage, version))?
				staged = entries.map(|entry| Path.to_os_str(Path.join(stage, entry)))
				_ = Script.command("chmod").capture!(["0644"].concat(staged), ".", [])?
				_ = Script.Command.{ base: Cmd.new("touch").env_str("TZ", "UTC"), program: "touch" }.capture!(["-t", "198001010000"].concat(staged), ".", [])?
				# -X leaves out owner and timestamp extras, -D directory entries;
				# -@ reads the entries to add. TZ fixes how the time is stored.
				_ = Script.Command.{ base: Cmd.new("zip").env_str("TZ", "UTC"), program: "zip" }.capture!(["-q", "-X", "-D", Path.to_os_str(archive), "-@"], stage, Str.to_utf8(Str.join_with(entries, "\n")))?
				Ok({})
			},
		)?
		Script.info!("ARCHIVE", Path.display(archive))?
		Ok(archive)
	}

	## Unpack the docs of `version` from `archive` into `output/<version>`,
	## which must not exist. Every entry is checked before anything is written,
	## so an archive cannot write outside that directory or create links. The
	## archive is a zip, or the tarball that releases up to 0.13.1 attached.
	restore! = |archive, version, output| {
		if !Release.valid_version(version) {
			return Script.fail!("not a release version: ${version}")
		}
		tarball = Path.display(archive).ends_with(".tar.gz")
		listed = if tarball list_tarball!(archive)? else list_zip!(archive)?
		entries = listed.entries
		# The long listing starts each line with the entry type: `-` is a
		# regular file and `d` a directory.
		if listed.kinds.len() != entries.len() or listed.kinds.any(|kind| !kind.starts_with("-") and !kind.starts_with("d")) {
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
		_ = if tarball {
			Script.command("tar").capture!(["-xzf", Path.to_os_str(archive), "--no-same-owner", "--no-same-permissions", "-C", Path.to_os_str(stage)], ".", [])?
		} else {
			Script.command("unzip").capture!(["-q", Path.to_os_str(archive), "-d", Path.to_os_str(stage)], ".", [])?
		}
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
	if !Release.valid_docs_version(version) {
		return Ok({})
	}
	asset_name = match Release.find_docs_archive(version, release.assets.map(|candidate| candidate.name)) {
		Zip(name) => name
		LegacyTarball(name) => name
		# Releases before 0.8.0 never attached documentation.
		Missing => return Ok({})
	}
	asset = match release.assets.keep_if(|candidate| candidate.name == asset_name) {
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

# The entry names of a zip, and the long listing lines that describe them.
list_zip! = |archive| {
	unzip = Script.command("unzip")
	entries = Text.lines(unzip.capture_utf8!(["-Z1", Path.to_os_str(archive)], ".")?)
	# -Z -s prints one line per entry, between two header lines and a line of
	# totals that starts with the number of files.
	kinds = Text.lines(unzip.capture_utf8!(["-Z", "-s", Path.to_os_str(archive)], ".")?)
		.keep_if(|line| !line.starts_with("Archive:") and !line.starts_with("Zip file size:") and !Text.is_digits(Str.from_utf8_lossy(Str.to_utf8(line).take_first(1))))
	Ok({ entries, kinds })
}

list_tarball! = |archive| {
	tar = Script.command("tar")
	entries = Text.lines(tar.capture_utf8!(["-tzf", Path.to_os_str(archive)], ".")?)
	kinds = Text.lines(tar.capture_utf8!(["-tvzf", Path.to_os_str(archive)], ".")?)
	Ok({ entries, kinds })
}

sha256! = |path| {
	report = Script.command("shasum").capture_utf8!(["-a", "256", Path.to_os_str(path)], ".")?
	match Str.split_first(report, " ") {
		Ok({ before, .. }) => Ok(before)
		Err(_) => Err(UnreadableDigest(report))
	}
}
