app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "../package/main.roc",
}

import pf.Stdout
import ansi.ANSI
import ansi.Style

main! = |_args| {
	lines = [
		ANSI.style("Bold On", [Style.Bold(On), Style.Default]),
		ANSI.style("Faint On", [Style.Faint(On), Style.Default]),
		ANSI.style("Italic On", [Style.Italic(On), Style.Default]),
		ANSI.style("Strikethrough On", [Style.Strikethrough(On), Style.Default]),
		ANSI.style("Underline On", [Style.Underline(On), Style.Default]),
		ANSI.style("Invert On", [Style.Invert(On), Style.Default]),
		ANSI.style("Combination", [Style.Bold(On), Style.Italic(On), Style.Strikethrough(On), Style.Underline(On), Style.Default]),
		"This should not have any style",
	]

	Stdout.line!(Str.join_with(lines, "\n"))
	Ok({})
}
