import cli.Env
import cli.OsStr
import cli.Path
import Files
import Headers
import Release
import Script
import Text

## The examples archive attached to each release.
##
## It holds complete copies of the examples in which the package dependency is
## that release's bundle URL, so they keep working exactly as published, and
## the specification of what they print. The examples in the repository always
## depend on the working tree instead.
Archive := [].{

	## The specification of what the working tree's examples print.
	spec : Path
	spec = "tests/spec.json"

	## The archive named by `EXAMPLES_ARCHIVE`, or the only one in `directory`
	## when that is unset.
	selected! = |directory| {
		match Script.env_or!("EXAMPLES_ARCHIVE", "")? {
			"" => {}
			named => return Ok(Path.utf8(named))
		}
		entries = if Path.is_dir!(directory)? Path.list!(directory)? else []
		match entries.keep_if(|path| Path.display(path).ends_with(".zip") and Path.display(path).contains("${Release.name}-examples-")) {
			[archive] => Ok(archive)
			[] => Script.fail!("no examples archive in ${Path.display(directory)}: package one first, or set EXAMPLES_ARCHIVE")
			_ => Script.fail!("several examples archives in ${Path.display(directory)}: set EXAMPLES_ARCHIVE to choose one")
		}
	}

	## Write the archive for the release `version`, whose bundle is named
	## `bundle_file`, into `output_dir`. Returns the path of the archive.
	pack! = |version, bundle_file, output_dir| {
		if Release.valid_version(version) and !Release.publishable_version(version) {
			return Script.fail!("version ${version} is reserved by Roc: the lowest publishable version is 0.0.1")
		}
		url = match Release.bundle_url(version, bundle_file) {
			Ok(value) => value
			Err(InvalidVersion(_)) => return Script.fail!("not a release version: ${version}")
			Err(InvalidBundleFile(_)) => return Script.fail!("not a bundle file name: ${bundle_file}")
		}
		root = Release.examples_root(version)
		Path.create_all!(output_dir)?
		archive = Path.join(Path.absolute!(output_dir)?, Release.examples_archive(version))
		# zip adds to an existing archive, which would keep entries from an earlier run.
		if Path.exists!(archive)? {
			Path.delete!(archive)?
		}

		Env.with_temp_dir!(
			|temporary| {
				stage = Path.join(temporary, root)
				staged_examples = Path.join(stage, "examples")
				Path.create_all!(staged_examples)?
				names = stage_examples!(Files.direct_roc_files!("examples")?, staged_examples, url, [])?
				Path.write_utf8!(Path.join(stage, "README.md"), Release.examples_readme(version, url))?
				Path.copy!(Archive.spec, Path.join(stage, "spec.json"))?
				entries = ["${root}/README.md", "${root}/spec.json"].concat(names.map(|name| "${root}/examples/${name}"))
				# -X leaves out owner and timestamp extras; -@ reads the entries to add.
				_ = Script.command("zip").capture!(["-q", "-X", Path.to_os_str(archive), "-@"], temporary, Str.to_utf8(Str.join_with(entries, "\n")))?
				Ok({})
			},
		)?
		Script.info!("ARCHIVE", "${Path.display(archive)} with ${Release.shorthand}: \"${url}\"")?
		Ok(archive)
	}

	## Unpack `archive` into `destination`, which must not exist yet, after
	## checking that it holds nothing but examples of one roc-ansi release.
	## Returns the directory of examples, the bundle URL they depend on, and
	## what to compare their output with: the archived specification, or
	## `ExitCodeOnly` for a release published before archives carried one.
	unpack! = |archive, destination| {
		Script.require_file!(archive)?
		file_name = Script.file_name(archive)?
		Path.create_all!(destination)?
		examples = if file_name.ends_with(".zip") {
			unzip!(archive, file_name.drop_suffix(".zip"), destination)?
		} else if file_name.ends_with(".tar.gz") {
			untar!(archive, destination)?
		} else {
			return Script.fail!("not an examples archive: ${file_name}")
		}
		archived_spec = Path.join(Path.join(destination, file_name.drop_suffix(".zip")), "spec.json")
		expected = if Path.is_file!(archived_spec)? Recorded(archived_spec) else ExitCodeOnly

		sources = Files.roc_sources!(examples)?
		urls = sources.map_try(|example| Headers.dependency(example.source, Release.shorthand))?
		url = match urls {
			[first, .. as rest] if rest.all(|other| other == first) => first
			[] => return Script.fail!("the examples archive holds no examples")
			_ => return Script.fail!("every archived example must depend on the same ${Release.name} bundle")
		}
		version = match Release.version_of_bundle_url(url) {
			Ok(value) => value
			Err(_) => return Script.fail!("archived examples must depend on a published ${Release.name} release bundle, not ${url}")
		}
		if file_name.ends_with(".zip") {
			if file_name != Release.examples_archive(version) {
				return Script.fail!("${file_name} holds examples of release ${version}")
			}
			if sources.any(|example| Headers.has_roc_pin(example.source)) {
				return Script.fail!("archived examples must not pin a Roc compiler")
			}
		}
		Ok({ examples, url, version, expected })
	}
}

stage_examples! = |examples, staged_examples, url, names|
	match examples {
		[example, .. as rest] => {
			name = Script.file_name(example)?
			source = Path.read_utf8!(example)?
			Path.write_utf8!(Path.join(staged_examples, name), Headers.with_dependency(source, Release.shorthand, url)?)?
			stage_examples!(rest, staged_examples, url, names.append(name))
		}
		[] => Ok(names)
	}

unzip! = |archive, root, destination| {
	unzip = Script.command("unzip")
	# -Z1 lists entry names, one per line, without unpacking anything.
	entries = Text.lines(unzip.capture_utf8!(["-Z1", Path.to_os_str(archive)], ".")?)
	match entries.keep_if(|entry| !Release.valid_examples_entry(root, entry)) {
		[] => {}
		[entry, ..] => return Script.fail!("unexpected entry in the examples archive: ${entry}")
	}
	_ = unzip.capture!(["-q", Path.to_os_str(archive), "-d", Path.to_os_str(destination)], ".", [])?
	Ok(Path.join(Path.join(destination, root), "examples"))
}

# Releases up to 0.13.1 attached a flat tarball of `examples/*.roc`.
untar! = |archive, destination| {
	tar = Script.command("tar")
	entries = Text.lines(tar.capture_utf8!(["-tzf", Path.to_os_str(archive)], ".")?)
	# The verbose listing starts each line with the entry type; `-` is a regular file.
	kinds = Text.lines(tar.capture_utf8!(["-tvzf", Path.to_os_str(archive)], ".")?)
	if kinds.len() != entries.len() or kinds.any(|kind| !kind.starts_with("-")) {
		return Script.fail!("the examples archive must hold only regular files")
	}
	match entries.keep_if(|entry| !Release.valid_legacy_examples_entry(entry)) {
		[] => {}
		[entry, ..] => return Script.fail!("unexpected entry in the examples archive: ${entry}")
	}
	_ = tar.capture!(["-xzf", Path.to_os_str(archive), "-C", Path.to_os_str(destination)], ".", [])?
	Ok(Path.join(destination, "examples"))
}
