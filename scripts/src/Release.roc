import Text

## Names and URLs of what a roc-ansi release publishes.
Release := [].{

	## The repository that publishes releases, in owner/name form.
	repository : Str
	repository = "lukewilliamboswell/roc-ansi"

	## The package name used in asset names.
	name : Str
	name = "roc-ansi"

	## The shorthand applications give the package in their header.
	shorthand : Str
	shorthand = "ansi"

	## Whether `value` is a release version: `x.y.z`, optionally with a
	## `-prerelease` suffix.
	valid_version : Str -> Bool
	valid_version = |value|
		match Str.split_first(value, "-") {
			Ok({ before, after }) => core_version(before) and Text.is_plain(after, ".-")
			Err(_) => core_version(value)
		}

	## Whether `value` is a version that has API documentation: exactly `x.y.z`.
	valid_docs_version : Str -> Bool
	valid_docs_version = |value| core_version(value)

	## The `x.y.z` that `version` is a release or a prerelease of.
	base_version : Str -> Str
	base_version = |version|
		match Str.split_first(version, "-") {
			Ok({ before, .. }) => before
			Err(_) => version
		}

	## Where the notes of the release `version` are written.
	notes_file : Str -> Str
	notes_file = |version| "docs/releases/${version}.adoc"

	## Whether `value` is the file name `roc bundle` gives a package archive.
	valid_bundle_file : Str -> Bool
	valid_bundle_file = |value| value.ends_with(".tar.zst") and Text.is_alphanumeric(value.drop_suffix(".tar.zst"))

	## The immutable URL of a bundle attached to the release `version`.
	bundle_url : Str, Str -> Try(Str, [InvalidVersion(Str), InvalidBundleFile(Str)])
	bundle_url = |version, bundle_file|
		if !Release.valid_version(version) {
			Err(InvalidVersion(version))
		} else if !Release.valid_bundle_file(bundle_file) {
			Err(InvalidBundleFile(bundle_file))
		} else {
			Ok("https://github.com/${Release.repository}/releases/download/${version}/${bundle_file}")
		}

	## The release version a bundle URL belongs to, if it is one of this
	## repository's immutable release bundle URLs.
	version_of_bundle_url : Str -> Try(Str, [NotAReleaseBundle(Str)])
	version_of_bundle_url = |url|
		match Str.split_on(url.drop_prefix("https://github.com/${Release.repository}/releases/download/"), "/") {
			[version, bundle_file] if Release.bundle_url(version, bundle_file) == Ok(url) => Ok(version)
			_ => Err(NotAReleaseBundle(url))
		}

	## The single top-level directory of the examples archive.
	examples_root : Str -> Str
	examples_root = |version| "${Release.name}-examples-${version}"

	## The examples archive attached to the release `version`.
	examples_archive : Str -> Str
	examples_archive = |version| "${Release.examples_root(version)}.zip"

	## Pick the examples archive out of the asset names of the release `version`.
	find_examples_archive : Str, List(Str) -> [Zip(Str), Missing]
	find_examples_archive = |version, assets|
		if assets.contains(Release.examples_archive(version)) Zip(Release.examples_archive(version)) else Missing

	## Whether `entry` may appear in the examples archive whose top-level
	## directory is `root`: the README, the expected-output specification, or
	## a Roc file directly inside `examples`.
	valid_examples_entry : Str, Str -> Bool
	valid_examples_entry = |root, entry|
		entry == "${root}/README.md" or entry == "${root}/spec.json" or example_file(entry.drop_prefix("${root}/examples/")) and entry.starts_with("${root}/examples/")

	## Whether `version` can be in a package URL. Roc reads 0.0.0 there as "no
	## version" and rejects the URL, so the lowest usable version is 0.0.1.
	publishable_version : Str -> Bool
	publishable_version = |version| Release.valid_version(version) and version != "0.0.0" and !version.starts_with("0.0.0-")

	## The version a pull request builds and tests its release under. It is
	## never published.
	dry_run_version : Str
	dry_run_version = "0.0.1-dry-run"

	## The documentation archive attached to the release `version`.
	docs_archive : Str -> Str
	docs_archive = |version| "${Release.name}-docs-${version}.zip"

	## Pick the documentation archive out of the asset names of the release
	## `version`. Releases up to 0.13.1 attached a `.tar.gz` instead of a `.zip`.
	find_docs_archive : Str, List(Str) -> [Zip(Str), LegacyTarball(Str), Missing]
	find_docs_archive = |version, assets| {
		legacy = "${Release.name}-docs-${version}.tar.gz"
		if assets.contains(Release.docs_archive(version)) {
			Zip(Release.docs_archive(version))
		} else if assets.contains(legacy) {
			LegacyTarball(legacy)
		} else {
			Missing
		}
	}

	## Whether `entry` may appear in the documentation archive of `version`:
	## a path beneath the `version` directory that cannot escape it.
	valid_docs_entry : Str, Str -> Bool
	valid_docs_entry = |version, entry|
		match Str.split_on(entry.drop_suffix("/"), "/") {
			[first, .. as rest] => first == version and !entry.contains("\\") and rest.all(|segment| segment != "" and segment != "." and segment != "..")
			[] => Bool.False
		}

	## The address the documentation site is served from.
	site : Str
	site = "https://lukewilliamboswell.github.io/roc-ansi"

	## The part of the manual that names one release: a first program whose
	## header holds that release's bundle `url`, and links to its API
	## reference, examples and notes. It is AsciiDoc, generated because a
	## bundle URL holds a hash that cannot be written by hand.
	install_snippet : Str, Str, Str -> Str
	install_snippet = |version, url, examples_asset| {
		release = "https://github.com/${Release.repository}/releases"
		Str.join_with(
			[
				".The latest release is ${version}",
				"[source,roc]",
				"----",
				"app [main!] {",
				"\tansi: \"${url}\",",
				"}",
				"",
				"import ansi.ANSI",
				"",
				"main! = |_args| {",
				"\techo!(ANSI.color(\"hello\", { fg: Standard(Green), bg: Default }))",
				"\tOk({})",
				"}",
				"----",
				"",
				"For release ${version}:",
				"",
				"* ${Release.site}/${version}/[API reference]",
				"* ${release}/download/${version}/${examples_asset}[Examples], each depending on this release",
				"* ${release}/tag/${version}[Release notes]",
				"",
			],
			"\n",
		)
	}

	## Order `x.y.z` versions from newest to oldest, comparing numbers, not text.
	newest_first : List(Str) -> List(Str)
	newest_first = |versions|
		List.sort_with(versions.map(|version| (numbers(version), version)), |(left, _), (right, _)| compare_numbers(right, left))
			.map(|(_, version)| version)

	## The part of the manual that links the API reference of every version
	## on the site: `main`, then each of `versions`, newest first. AsciiDoc.
	api_versions : List(Str) -> Str
	api_versions = |versions|
		Str.join_with(
			["* ${Release.site}/main/[main], which is not released yet"]
				.concat(Release.newest_first(versions).map(|version| "* ${Release.site}/${version}/[${version}]"))
				.append(""),
			"\n",
		)

	## The README at the top of the examples archive.
	examples_readme : Str, Str -> Str
	examples_readme = |version, url|
		Str.join_with(
			[
				"# ${Release.name} ${version} examples",
				"",
				"These are the ${Release.name} examples as they were when ${version} was released.",
				"Each application depends on that release's package:",
				"",
				"    ${url}",
				"",
				"Install the Roc compiler named in the release notes, then run an example",
				"from the `examples` directory:",
				"",
				"    cd examples",
				"    roc colors.roc",
				"",
				"`spec.json` records what each example printed when ${version} was released.",
				"",
				"Release notes: https://github.com/${Release.repository}/releases/tag/${version}",
				"",
			],
			"\n",
		)
}

numbers = |version| Str.split_on(version, ".").map(|part| U64.from_str(part).ok_or(0))

compare_numbers = |left, right|
	match (left, right) {
		([a, .. as left_rest], [b, .. as right_rest]) =>
			if a < b Before else if a > b After else compare_numbers(left_rest, right_rest)
		([], []) => Same
		([], _) => Before
		(_, []) => After
	}

example_file = |file_name| file_name.ends_with(".roc") and Text.is_plain(file_name.drop_suffix(".roc"), "-_")

core_version = |value|
	match Str.split_on(value, ".") {
		[major, minor, patch] => Text.is_digits(major) and Text.is_digits(minor) and Text.is_digits(patch)
		_ => Bool.False
	}

url = "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.14.0/Abc123.tar.zst"

expect Release.valid_version("0.14.0") and Release.valid_version("1.0.0-rc.1")
expect !Release.valid_version("0.14") and !Release.valid_version("v0.14.0") and !Release.valid_version("0.14.0-") and !Release.valid_version("0.14.0/x") and !Release.valid_version("latest")
expect Release.valid_docs_version("0.14.0") and !Release.valid_docs_version("1.0.0-rc.1")
expect Release.valid_bundle_file("Abc123.tar.zst") and !Release.valid_bundle_file("../Abc123.tar.zst") and !Release.valid_bundle_file(".tar.zst") and !Release.valid_bundle_file("Abc123.tar.gz")
expect Release.bundle_url("0.14.0", "Abc123.tar.zst") == Ok(url)
expect Release.bundle_url("latest", "Abc123.tar.zst") == Err(InvalidVersion("latest"))
expect Release.bundle_url("0.14.0", "a/b.tar.zst") == Err(InvalidBundleFile("a/b.tar.zst"))
expect Release.version_of_bundle_url(url) == Ok("0.14.0")
expect Release.version_of_bundle_url("http://127.0.0.1:8000/Abc123.tar.zst").is_err()
expect Release.version_of_bundle_url("../package/main.roc").is_err()
expect Release.version_of_bundle_url("https://github.com/someone/roc-ansi/releases/download/0.14.0/Abc123.tar.zst").is_err()
expect Release.version_of_bundle_url("https://github.com/lukewilliamboswell/roc-ansi/releases/download/latest/Abc123.tar.zst").is_err()
expect Release.examples_archive("0.14.0") == "roc-ansi-examples-0.14.0.zip"
expect Release.find_examples_archive("0.14.0", ["Abc123.tar.zst", "roc-ansi-docs-0.14.0.zip", "roc-ansi-examples-0.14.0.zip"]) == Zip("roc-ansi-examples-0.14.0.zip")
expect Release.find_examples_archive("0.13.1", ["roc-ansi-examples-0.13.1.tar.gz"]) == Missing
expect Release.find_examples_archive("0.14.0", ["roc-ansi-examples-0.13.1.zip"]) == Missing
expect Release.docs_archive("0.14.0") == "roc-ansi-docs-0.14.0.zip"
expect Release.find_docs_archive("0.14.0", ["Abc123.tar.zst", "roc-ansi-docs-0.14.0.zip"]) == Zip("roc-ansi-docs-0.14.0.zip")
expect Release.find_docs_archive("0.13.1", ["roc-ansi-docs-0.13.1.tar.gz", "roc-ansi-examples-0.13.1.tar.gz"]) == LegacyTarball("roc-ansi-docs-0.13.1.tar.gz")
expect Release.find_docs_archive("0.7.0", ["Abc123.tar.zst"]) == Missing and Release.find_docs_archive("0.14.0", ["roc-ansi-docs-0.13.1.zip"]) == Missing
expect Release.examples_readme("0.14.0", url).contains("    ${url}\n") and Release.examples_readme("0.14.0", url).ends_with("/releases/tag/0.14.0\n")
expect Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/README.md")
expect Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/spec.json") and !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/examples/spec.json")
expect Release.publishable_version("0.0.1-dry-run") and Release.publishable_version("0.14.0") and !Release.publishable_version("0.0.0") and !Release.publishable_version("0.0.0-rc1") and !Release.publishable_version("latest")
expect Release.publishable_version(Release.dry_run_version)
expect Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/examples/menu.roc")
expect !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/examples/../../escape.roc")
expect !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/examples/nested/app.roc")
expect !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/examples/notes.txt")
expect !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.13.0/examples/colors.roc")
expect !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "/etc/passwd")
expect !Release.valid_examples_entry("roc-ansi-examples-0.14.0", "roc-ansi-examples-0.14.0/examples/.roc")
expect Release.valid_docs_entry("0.14.0", "0.14.0/index.html") and Release.valid_docs_entry("0.14.0", "0.14.0/ANSI/") and Release.valid_docs_entry("0.14.0", "0.14.0")
expect !Release.valid_docs_entry("0.14.0", "../escape") and !Release.valid_docs_entry("0.14.0", "/escape") and !Release.valid_docs_entry("0.14.0", "0.14.0/../../escape")
expect !Release.valid_docs_entry("0.14.0", "0.13.0/index.html") and !Release.valid_docs_entry("0.14.0", "0.14.0//index.html") and !Release.valid_docs_entry("0.14.0", "0.14.0/a\\b") and !Release.valid_docs_entry("0.14.0", "")
expect Release.install_snippet("0.14.0", url, "roc-ansi-examples-0.14.0.zip").contains("\tansi: \"${url}\",\n")
expect Release.install_snippet("0.14.0", url, "roc-ansi-examples-0.14.0.zip").contains("* https://lukewilliamboswell.github.io/roc-ansi/0.14.0/[API reference]\n* https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.14.0/roc-ansi-examples-0.14.0.zip[Examples]")
expect Release.newest_first(["0.9.0", "0.13.1", "0.10.0", "0.13.0"]) == ["0.13.1", "0.13.0", "0.10.0", "0.9.0"]
expect Release.api_versions(["0.9.0", "0.10.0"]) == "* https://lukewilliamboswell.github.io/roc-ansi/main/[main], which is not released yet\n* https://lukewilliamboswell.github.io/roc-ansi/0.10.0/[0.10.0]\n* https://lukewilliamboswell.github.io/roc-ansi/0.9.0/[0.9.0]\n"
expect Release.base_version("0.14.0") == "0.14.0" and Release.base_version("1.0.0-rc.1") == "1.0.0"
expect Release.notes_file("0.14.0") == "docs/releases/0.14.0.adoc"
