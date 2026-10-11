#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
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
## release would publish are checked with the `roc` on PATH, or `ROC_NIGHTLY`,
## which is meant to be the latest nightly.
main! = |_args| {
	roc_stable = Script.roc_stable!()?
	roc_nightly = Script.roc_nightly!()?

	Script.section!("Compilers")?
	roc_stable.run!(["version"])?
	roc_nightly.run!(["version"])?

	check_compiler_pins!()?
	check_scripts!(roc_stable)?
	check_package!(roc_nightly)?
	check_examples!(roc_nightly)?
	check_release_artifacts!(roc_nightly)?
	check_site!(roc_nightly)?

	Script.section!("Whitespace")?
	Script.command("git").run!(["diff", "--check"])
}

# The tooling compiler is named in Blueprint.roc and the package compiler
# floats, so a pin anywhere else is always a mistake.
check_compiler_pins! = || {
	Script.section!("Compiler pins")?
	for stale in [".roc-version", ".github/roc-nightly.json"] {
		if Path.exists!(Path.utf8(stale))? {
			return Script.fail!("${stale} must not exist: this repository does not pin the package compiler")
		}
	}
	for directory in ["package", "examples", "scripts"] {
		for file in Files.roc_sources!(Path.utf8(directory))? {
			if Headers.has_roc_pin(file.source) {
				return Script.fail!("${Path.display(file.path)}: remove the `roc:` header field")
			}
		}
	}
	Script.pass!("no Roc compiler pins")
}

check_scripts! = |roc_stable| {
	Script.section!("Scripts, with the tooling compiler")?
	# The modules without effects carry the tests of the scripts' logic.
	for module_name in ["Headers", "Html", "Release", "Text"] {
		roc_stable.run!(["test", "scripts/src/${module_name}.roc"])?
	}
	for script in Files.direct_roc_files!("scripts")? {
		roc_stable.run!(["check", Path.to_os_str(script)])?
	}
	roc_stable.run!(["fmt", "--check", "scripts"])
}

check_package! = |roc_nightly| {
	Script.section!("Package")?
	roc_nightly.run!(["fmt", "--check", "package", "examples"])?
	roc_nightly.run!(["check", "package/main.roc", "--no-cache"])?
	roc_nightly.run!(["test", "package/main.roc", "--no-cache"])
}

check_examples! = |roc_nightly| {
	Script.section!("Examples, against the working tree")?
	# Committed examples must exercise the working tree, never a published bundle.
	for example in Files.roc_sources!("examples")? {
		match Headers.dependency(example.source, Release.shorthand) {
			Ok("../package/main.roc") => {}
			_ => return Script.fail!("${Path.display(example.path)}: the app header must declare ${Release.shorthand}: \"../package/main.roc\"")
		}
	}
	Examples.exercise!(roc_nightly, "examples", Direct)
}

# Build what a release would publish, and test that instead of the source tree.
check_release_artifacts! = |roc_nightly| {
	Script.section!("Release bundle and examples archive")?
	Env.with_temp_dir!(
		|temporary| {
			output = Path.join(temporary, "dist")
			bundle = Bundle.build!(roc_nightly, output)?
			Bundle.test!(roc_nightly, bundle)?

			# The archive's URL does not exist until a release is published, so
			# here it is unpacked and compared instead of run.
			archive = Archive.pack!("0.0.0", Script.file_name(bundle)?, output)?
			unpacked = Archive.unpack!(archive, Path.join(temporary, "unpacked"))?
			for example in Files.roc_sources!("examples")? {
				archived = Path.read_utf8!(Path.join(unpacked.examples, Script.file_name(example.path)?))?
				if Headers.with_dependency(example.source, Release.shorthand, unpacked.url) != Ok(archived) {
					return Script.fail!("the archived ${Path.display(example.path)} differs by more than its package dependency")
				}
			}
			Script.pass!("archived examples differ from the repository's only in the package dependency")
		},
	)
}

check_site! = |roc_nightly| {
	Script.section!("Documentation site and docs archive")?
	Env.with_temp_dir!(
		|temporary| {
			Site.assemble!(roc_nightly, Path.join(temporary, "site"), SkipReleaseDocs)?

			docs_root = Path.join(temporary, "docs")
			Site.docs!(roc_nightly, Path.join(docs_root, "0.0.0"))?
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
