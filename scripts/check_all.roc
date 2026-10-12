#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Env
import cli.Path
import src/Archive
import src/Bundle
import src/DocsArchive
import src/Examples
import src/Files
import src/Headers
import src/Release
import src/Script
import src/Site

## Everything CI checks, in one command.
##
##     blueprint run check
##
## Two compilers take part. `roc-stable`, pinned by Blueprint.roc, runs this
## script and checks the other scripts. The package, the examples and what a
## release would publish are checked with the `roc` on PATH, which is meant to
## be the latest nightly.
main! = |_args| {
	roc_stable = Script.roc_stable!()?
	roc = Script.roc!()?

	Script.section!("Compilers")?
	roc_stable.run!(["version"])?
	roc.run!(["version"])?

	check_compiler_pins!()?
	check_scripts!(roc_stable)?
	check_package!(roc)?
	check_examples!(roc)?
	check_release_artifacts!(roc)?
	check_site!(roc)?

	Script.section!("Whitespace")?
	Script.command("git").run!(["diff", "--check"])
}

# The package compiler floats, so nothing outside scripts/ names a compiler.
# Each script names the tooling compiler, and Blueprint.roc is the authority:
# someone who runs a script with another `roc` is then told why it misbehaves.
check_compiler_pins! = || {
	Script.section!("Compiler pins")?
	for stale in [".roc-version", ".github/roc-nightly.json"] {
		if Path.exists!(Path.utf8(stale))? {
			return Script.fail!("${stale} must not exist: this repository does not pin the package compiler")
		}
	}
	for directory in ["package", "examples"] {
		for file in Files.roc_sources!(Path.utf8(directory))? {
			if Headers.has_roc_pin(file.source) {
				return Script.fail!("${Path.display(file.path)}: remove the `roc:` header field")
			}
		}
	}
	tag = match Headers.stable_tag(Path.read_utf8!("Blueprint.roc")?) {
		Ok(value) => value
		Err(NoStableCompiler) => return Script.fail!("Blueprint.roc does not name roc-stable with Command(\"roc-stable\", \"rocpkgs.<tag>\")")
	}
	for file in Files.roc_sources!("scripts")?.keep_if(|script| Headers.is_app(script.source)) {
		if Headers.roc_pin(file.source) != Ok(tag) {
			return Script.fail!("${Path.display(file.path)}: the app header must declare roc: \"${tag}\", the roc-stable release in Blueprint.roc")
		}
	}
	Script.pass!("only the scripts name a compiler, and it is ${tag}")
}

check_scripts! = |roc_stable| {
	Script.section!("Scripts, with the tooling compiler")?
	# The modules without effects carry the tests of the scripts' logic.
	for module_name in ["Headers", "Html", "Release", "Report", "Spec", "Text"] {
		roc_stable.run!(["test", "scripts/src/${module_name}.roc"])?
	}
	for script in Files.direct_roc_files!("scripts")? {
		roc_stable.run!(["check", Path.to_os_str(script)])?
	}
	roc_stable.run!(["fmt", "--check", "scripts"])
}

check_package! = |roc| {
	Script.section!("Package")?
	roc.run!(["fmt", "--check", "package", "examples"])?
	roc.run!(["check", "package/main.roc", "--no-cache"])?
	roc.run!(["test", "package/main.roc", "--no-cache"])
}

check_examples! = |roc| {
	Script.section!("Examples, against the working tree")?
	# Committed examples must exercise the working tree, never a published bundle.
	for example in Files.roc_sources!("examples")? {
		match Headers.dependency(example.source, Release.shorthand) {
			Ok("../package/main.roc") => {}
			_ => return Script.fail!("${Path.display(example.path)}: the app header must declare ${Release.shorthand}: \"../package/main.roc\"")
		}
	}
	Examples.run!(roc, { directory: "examples", source: Direct, expected: Recorded("tests/spec.json"), mode: Compare, roc_args: [] })
}

# Build what a release would publish, and test those files instead of the
# source tree.
check_release_artifacts! = |roc| {
	Script.section!("Release bundle and examples archive")?
	Env.with_temp_dir!(
		|temporary| {
			output = Path.join(temporary, "dist")
			bundle = Bundle.build!(roc, output)?
			archive = Archive.pack!(Release.dry_run_version, Script.file_name(bundle)?, output)?
			Bundle.test!(roc, bundle, archive)?

			unpacked = Archive.unpack!(archive, Path.join(temporary, "unpacked"))?
			for example in Files.roc_sources!("examples")? {
				archived = Path.read_utf8!(Path.join(unpacked.examples, Script.file_name(example.path)?))?
				if Headers.with_dependency(example.source, Release.shorthand, unpacked.url) != Ok(archived) {
					return Script.fail!("the archived ${Path.display(example.path)} differs by more than its package dependency")
				}
			}
			match unpacked.expected {
				Recorded(archived_spec) if Path.read_utf8!(archived_spec)? == Path.read_utf8!(Archive.spec)? => {}
				_ => return Script.fail!("the examples archive does not hold ${Path.display(Archive.spec)} unchanged")
			}
			Script.pass!("archived examples differ from the repository's only in the package dependency")
		},
	)
}

check_site! = |roc| {
	Script.section!("Documentation site and docs archive")?
	Env.with_temp_dir!(
		|temporary| {
			Site.assemble!(roc, Path.join(temporary, "site"), SkipReleaseDocs)?

			docs_root = Path.join(temporary, "docs")
			Site.docs!(roc, Path.join(docs_root, "0.0.0"))?
			first = DocsArchive.pack!(docs_root, "0.0.0", Path.join(temporary, "first"))?
			second = DocsArchive.pack!(docs_root, "0.0.0", Path.join(temporary, "second"))?
			if Path.read_bytes!(first)? != Path.read_bytes!(second)? {
				return Script.fail!("packing the same documentation twice gave different archives")
			}
			restored = Path.join(temporary, "restored")
			DocsArchive.restore!(first, "0.0.0", restored)?
			Script.require_file!(Path.join(Path.join(restored, "0.0.0"), "index.html"))?
			Script.pass!("documentation archive is reproducible and restores")
		},
	)
}
