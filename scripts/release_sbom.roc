#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Env
import cli.OsStr
import cli.Path
import src/Bundle
import src/Files
import src/Release
import src/Script
import src/Text

## Artifact-bound source inventory. All rendering and format/graph validation
## use Blueprint's immutable native SBOM utility, not a local format adapter.
main! = |_args| {
	version = Script.env!("RELEASE_VERSION")?
	if !Release.publishable_version(version) {
		return Script.fail!("invalid release version")
	}
	bundle = Bundle.selected!("dist")?
	filename = Script.file_name(bundle)?
	url = Release.bundle_url(version, filename).map_err(|_| InvalidVersion)?
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
	created = Script.command("env").capture_utf8!(["TZ=UTC", "git", "show", "-s", "--date=format-local:%Y-%m-%dT%H:%M:%SZ", "--format=%cd", "HEAD"], ".")?.trim()
	compiler = roc.capture_utf8!(["version"], ".")?.trim().drop_prefix("Roc compiler version ")
	if !compiler.starts_with("nightly-") or !Text.is_plain(compiler, "-.") {
		return Script.fail!("source SBOM requires an identifiable released nightly compiler")
	}
	compiler_path = Script.command("sh").capture_utf8!(["-c", "realpath \"$(command -v roc)\""], ".")?.trim()
	compiler_sha = digest!(Path.utf8(compiler_path))?
	digest = digest!(bundle)?
	members_path = Path.utf8("dist/${filename}.sbom-members.json")
	tool!(["members", Path.to_os_str(bundle), Path.to_os_str(members_path)])?
	listing : { archive : Str, sha256 : Str, members : List({ name : Str, size : U64, sha256 : Str }) }
	listing = Json.parse(Path.read_utf8!(members_path)?).map_err(|_| InvalidMemberListing)?
	if listing.archive != filename or listing.sha256 != digest {
		return Script.fail!("archive member listing describes different bundle bytes")
	}
	# Membership/HEAD checks above establish these are our reviewed UPL sources.
	archive_components = listing.members.map(
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
	archive_relationships = listing.members.map(
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
	inventory = Path.utf8("dist/${filename}.sbom-inventory.json")
	subject = { filename, version, target: "source", sha256: digest, url }
	context = {
		namespace: "https://github.com/${Release.repository}/sbom/${version}/${commit}/${filename}/revision-1",
		revision: "1",
		created,
		author: "Person: Luke Boswell",
		generator: "Tool: blueprint-sbom-0.8.0",
	}
	Env.with_temp_dir!(
		|temporary| {
			spec_path = Path.join(temporary, "Spec")
			composition_path = Path.join(temporary, "composition.json")
			subject_path = Path.join(temporary, "subject.json")
			context_path = Path.join(temporary, "context.json")
			Path.write_utf8!(spec_path, Script.command("blueprint").capture_utf8!(["spec"], ".")?)?
			Path.write_utf8!(composition_path, composition)?
			Path.write_utf8!(subject_path, Json.to_str(subject))?
			Path.write_utf8!(context_path, Json.to_str(context))?
			tool!(["inspect", Path.to_os_str(spec_path), "Blueprint.lock", Path.to_os_str(composition_path), "source", Path.to_os_str(inventory), "--members", Path.to_os_str(members_path)])?
			tool!(["bind", Path.to_os_str(inventory), Path.to_os_str(subject_path), Path.to_os_str(context_path), Path.to_os_str(bundle)])?
			tool!(["bind", Path.to_os_str(inventory), Path.to_os_str(subject_path), Path.to_os_str(context_path), Path.to_os_str(bundle), OsStr.from_str("dist/${filename}.spdx-2.3.json"), "--spdx-2.3", "--manifest", OsStr.from_str("dist/${filename}.spdx-2.3.sbom-manifest.json")])
		},
	)?
	manifests = ["${filename}.sbom-manifest.json", "${filename}.spdx-2.3.sbom-manifest.json"]
	for name in manifests {
		tool!(["check", "--manifest", OsStr.from_str("dist/${name}"), "--artifacts", "dist", "--inventory", Path.to_os_str(inventory)])?
	}
	sidecars = ["${filename}.spdx.json", "${filename}.cdx.json", "${filename}.spdx-2.3.json"]
	tool!(["check", "--artifacts", "dist", "--inventory", Path.to_os_str(inventory)].concat(sidecars.map(|name| OsStr.from_str("dist/${name}"))))?
	subject_bytes = Path.read_bytes!(bundle)?.len()
	inventory_sha256 = digest!(inventory)?
	run_id = Script.env_or!("GITHUB_RUN_ID", "local")?
	run_attempt = Script.env_or!("GITHUB_RUN_ATTEMPT", "local")?
	var $sidecar_records = []
	for name in sidecars {
		path = Path.utf8("dist/${name}")
		sha256 = digest!(path)?
		bytes = Path.read_bytes!(path)?.len()
		$sidecar_records = $sidecar_records.append({ filename: name, sha256, bytes })
	}
	var $manifest_records = []
	for name in manifests {
		path = Path.utf8("dist/${name}")
		sha256 = digest!(path)?
		bytes = Path.read_bytes!(path)?.len()
		$manifest_records = $manifest_records.append({ filename: name, sha256, bytes })
	}
	members_sha256 = digest!(members_path)?
	evidence = {
		schema_version: 1.U64,
		repository: Release.repository,
		source_commit: commit,
		created,
		run_id,
		run_attempt,
		subject: { filename, version, target: "source", sha256: digest, bytes: subject_bytes, url },
		inventory_sha256,
		sidecars: $sidecar_records,
		manifests: $manifest_records,
		members_sha256,
	}
	Path.write_utf8!(Path.utf8("dist/${filename}.sbom-evidence.json"), "${Json.to_str(evidence)}\n")?
	Script.pass!("source bundle SBOMs bound to ${digest}; SPDX 3.0.1, SPDX 2.3 and CycloneDX 1.7 agree")
}

tool! = |args| Script.command("blueprint-sbom").run!(args)

digest! = |path| {
	answer = Script.command("shasum").capture_utf8!(["-a", "256", Path.to_os_str(path)], ".")?
	match Str.split_first(answer, " ") {
		Ok({ before, .. }) if before.to_utf8().len() == 64 => Ok(before)
		_ => Script.fail!("invalid SHA-256 output")
	}
}
