#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Env
import cli.OsStr
import cli.Path
import src/Allocations
import src/Files
import src/Headers
import src/Release
import src/Script
import src/Site

## Everything checked before the release workflow packages anything.
##
##     blueprint run check
##
## Two compilers take part. `roc-stable`, pinned by Blueprint.roc, runs this
## script and checks the other scripts. The package and the fuzz targets are
## checked with the `roc` on PATH, which is meant to be the latest nightly. The
## examples, the bundle and the archives are the shared release workflow's job:
## `release-package test-examples` runs the examples against the working tree.
main! = |_args| {
	roc_stable = Script.roc_stable!()?
	roc = Script.roc!()?

	Script.section!("Compilers")?
	roc_stable.run!(["version"])?
	roc.run!(["version"])?

	check_compiler_pins!()?
	check_scripts!(roc_stable)?
	check_package!(roc)?
	check_fuzz_targets!(roc)?
	Script.section!("Allocation ceilings")?
	Allocations.check!(roc)?
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
	for directory in ["package", "examples", "fuzz", "tests"] {
		for file in Files.roc_sources!(Path.utf8(directory))? {
			if Headers.has_roc_pin(file.source) {
				return Script.fail!("${Path.display(file.path)}: remove the `roc:` header field")
			}
		}
	}
	tag = match Headers.stable_tag(Path.read_utf8!("Blueprint.roc")?) {
		Ok(value) => value
		Err(NoStableCompiler) => return Script.fail!("Blueprint.roc does not name roc-stable with Fetch(\"roc-stable\", Recipes.roc_nightly(\"<tag>\"))")
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
	for module_name in ["Headers", "Html", "Ratchet", "Release", "Report", "Text"] {
		roc_stable.run!(["test", "scripts/src/${module_name}.roc"])?
	}
	for script in Files.direct_roc_files!("scripts")? {
		roc_stable.run!(["check", Path.to_os_str(script)])?
	}
	roc_stable.run!(["fmt", "--check", "scripts"])
}

check_package! = |roc| {
	Script.section!("Package")?
	roc.run!(["fmt", "--check", "package", "examples", "fuzz", "tests"])?
	roc.run!(["check", "package/main.roc", "--no-cache"])?
	roc.run!(["test", "package/main.roc", "--no-cache"])
}

# A target that is never built goes stale, so each one is built on every pull
# request and replays its committed corpus. Searching for new inputs is left
# to a longer run: `<target> run fuzz/<name>/corpus`.
check_fuzz_targets! = |roc| {
	Script.section!("Fuzz targets, replaying their corpus")?
	Env.with_temp_dir!(
		|build| {
			for directory in Files.sort_paths(Path.list!("fuzz")?) {
				name = Script.file_name(directory)?
				target = Path.join(directory, "main.roc")
				match Headers.dependency(Path.read_utf8!(target)?, Release.shorthand) {
					Ok("../../package/main.roc") => {}
					_ => return Script.fail!("${Path.display(target)}: the app header must declare ${Release.shorthand}: \"../../package/main.roc\"")
				}
				inputs = Files.all_files!(Path.join(directory, "corpus"))?
				if inputs.is_empty() {
					return Script.fail!("${Path.display(directory)}: commit at least one input under corpus")
				}
				executable = Path.join(build, name)
				roc.run!(["build", "--fuzz", Path.to_os_str(target), OsStr.from_str("--output=${Path.display(executable)}"), "--no-cache"])?
				for input in inputs {
					_ = Script.command(Path.to_os_str(executable)).capture!(["replay", Path.to_os_str(input)], ".", [])?
				}
				Script.pass!("${name} replayed ${inputs.len().to_str()} inputs")?
			}
			Ok({})
		},
	)
}

check_site! = |roc| {
	Script.section!("Documentation site")?
	Env.with_temp_dir!(|temporary| Site.assemble!(roc, Path.join(temporary, "site"), SkipReleaseDocs))
}
