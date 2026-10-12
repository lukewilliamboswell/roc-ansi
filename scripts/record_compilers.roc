#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Script

## Record the compilers a release was built and tested with, for its notes.
##
##     scripts/record_compilers.roc
##
## Writes Markdown to `.release/compilers.md`, or to the file named by
## `OUTPUT`. No header pins the package compiler, so the release notes are
## where a release states what it was built with.
main! = |_args| {
	roc_stable = Script.roc_stable!()?
	roc_nightly = Script.roc_nightly!()?
	output = Path.utf8(Script.env_or!("OUTPUT", ".release/compilers.md")?)
	package_compiler = roc_nightly.capture_utf8!(["version"], ".")?.trim().drop_prefix("Roc compiler version ")
	tooling_compiler = roc_stable.capture_utf8!(["version"], ".")?.trim().drop_prefix("Roc compiler version ")
	notes = Str.join_with(
		[
			"",
			"## Compilers",
			"",
			"- Package and examples built and tested with `roc` ${package_compiler}",
			"- Release tooling run with `roc-stable` ${tooling_compiler}",
			"",
		],
		"\n",
	)
	match Str.split_last(Path.display(output), "/") {
		Ok({ before, .. }) => Path.create_all!(Path.utf8(before))?
		Err(_) => {}
	}
	Path.write_utf8!(output, notes)?
	Script.info!("COMPILERS", Path.display(output))
}
