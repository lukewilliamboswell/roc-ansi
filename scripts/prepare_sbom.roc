#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.OsStr
import cli.Path
import src/Files
import src/Script
import src/Text

## Check the bundle the release workflow built against the committed package
## source, and write the reviewed SBOM composition for it. The shared
## sbom-sidecars action owns generation, binding and validation.
##
##     RELEASE_VERSION=0.14.0 BUNDLE_PATH=dist/<hash>.tar.zst BUNDLE_URL=https://... scripts/prepare_sbom.roc
##
## The composition is written to `SBOM_COMPOSITION`, by default
## `dist/sbom-composition.json`, which is where the shared workflow reads it.
main! = |_args| {
	version = Script.env!("RELEASE_VERSION")?
	bundle = Path.utf8(Script.env!("BUNDLE_PATH")?)
	url = Script.env!("BUNDLE_URL")?
	output = Path.utf8(Script.env_or!("SBOM_COMPOSITION", "dist/sbom-composition.json")?)
	Script.require_file!(bundle)?
	roc = Script.roc!()?
	dependencies = roc.capture_utf8!(["deps", "package/main.roc"], ".")?.trim()
	if Text.lines(dependencies).len() != 1 or !dependencies.ends_with("[package]") {
		return Script.fail!("package dependency closure changed: review sbom/package.json before release")
	}
	# This recipe promises first-party source only. Added members or changed
	# source/dependency boundaries must receive a composition review.
	members = Text.lines(Script.command("tar").capture_utf8!(["-tf", Path.to_os_str(bundle)], ".")?)
	sources = Files.direct_roc_files!("package")?
	if members.len() != sources.len() {
		return Script.fail!("source bundle membership differs from the reviewed package")
	}
	tracked = Text.lines(Script.command("git").capture_utf8!(["ls-tree", "-r", "--name-only", "HEAD", "--", "package"], ".")?).keep_if(|name| name.ends_with(".roc"))
	if tracked.len() != sources.len() {
		return Script.fail!("package source membership differs from HEAD")
	}
	for source in sources {
		if !tracked.contains(Path.display(source)) or !Path.is_file!(source)? {
			return Script.fail!("package source is untracked or not a regular file")
		}
		name = Script.file_name(source)?
		if !members.contains(name) or Script.command("tar").capture!(["-xOf", Path.to_os_str(bundle), OsStr.from_str(name)], ".", [])? != Script.command("git").capture!(["show", OsStr.from_str("HEAD:${Path.display(source)}")], ".", [])? {
			return Script.fail!("source bundle differs from package/${name}")
		}
	}
	git = Script.command("git")
	git.run!(["diff", "--quiet", "HEAD", "--", "package", "LICENSE"])?
	commit = git.capture_utf8!(["rev-parse", "HEAD"], ".")?.trim()
	compiler = roc.capture_utf8!(["version"], ".")?.trim().drop_prefix("Roc compiler version ")
	if !compiler.starts_with("nightly-") or !Text.is_plain(compiler, "-.") {
		return Script.fail!("source SBOM requires an identifiable released nightly compiler")
	}
	compiler_path = Script.command("sh").capture_utf8!(["-c", "realpath \"$(command -v roc)\""], ".")?.trim()
	compiler_sha = digest!(Path.utf8(compiler_path))?
	digest = digest!(bundle)?
	var $members = []
	for source in sources {
		name = Script.file_name(source)?
		sha256 = digest!(source)?
		size = Path.read_bytes!(source)?.len()
		$members = $members.append({ name, sha256, size })
	}
	# Membership/HEAD checks above establish these are our reviewed UPL sources.
	archive_components = ($members).map(
		|member| {
			id: "member-${member.name.replace_each(".", "-")}",
			name: member.name,
			version: "sha256-${member.sha256}",
			identity: "urn:blueprint:archive-member:${member.name}:${member.sha256}",
			download: "NOASSERTION",
			sha256: member.sha256,
			license: "UPL-1.0",
			license_url: "",
			modified: "",
			target: "source",
			origin: "reviewed",
			producer: "Person: Luke Boswell",
		},
	)
	archive_relationships = ($members).map(
		|member| {
			from: "roc-ansi",
			to: "member-${member.name.replace_each(".", "-")}",
			relation: "contains",
			scope: "",
			basis: "Archive member checked against committed source; SHA-256 identifies the member bytes.",
		},
	)
	composition = Path.read_utf8!("sbom/package.json")?
		.replace_each("\"@ARCHIVE_COMPONENTS@\"", Json.to_str(archive_components).drop_prefix("[").drop_suffix("]"))
		.replace_each("\"@ARCHIVE_RELATIONSHIPS@\"", Json.to_str(archive_relationships).drop_prefix("[").drop_suffix("]"))
		.replace_each("@RELEASE@", version)
		.replace_each("@COMMIT@", commit)
		.replace_each("@BUNDLE_URL@", url)
		.replace_each("@BUNDLE_SHA256@", digest)
		.replace_each("@COMPILER_SHA256@", compiler_sha)
		.replace_each("@COMPILER@", compiler)
	match Str.split_last(Path.display(output), "/") {
		Ok({ before, .. }) => Path.create_all!(Path.utf8(before))?
		Err(_) => {}
	}
	Path.write_utf8!(output, composition)?
	Script.pass!("committed source and bundle bytes agree; reviewed member composition written to ${Path.display(output)}")
}

digest! = |path| {
	answer = Script.command("shasum").capture_utf8!(["-a", "256", Path.to_os_str(path)], ".")?
	match Str.split_first(answer, " ") {
		Ok({ before, .. }) if before.to_utf8().len() == 64 => Ok(before)
		_ => Script.fail!("invalid SHA-256 output")
	}
}
