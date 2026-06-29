app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "../package/main.roc",
}

import pf.Stdout
import ansi.ANSI
import ansi.Style

with_style : Str, List(ANSI.Style) -> Str
with_style = |text, styles| Str.concat(ANSI.style(text, styles), ANSI.style("", [Style.Default]))

main! = |_args| {
	lines = [
		with_style("Bold On", [Style.Bold(On)]),
		with_style("Faint On", [Style.Faint(On)]),
		with_style("Italic On", [Style.Italic(On)]),
		with_style("Strikethrough On", [Style.Strikethrough(On)]),
		with_style("Underline On", [Style.Underline(On)]),
		with_style("Invert On", [Style.Invert(On)]),
		with_style("Combination", [Style.Bold(On), Style.Italic(On), Style.Strikethrough(On), Style.Underline(On)]),
		"This should not have any style",
	]

	Stdout.line!(Str.join_with(lines, "\n"))
	Ok({})
}
