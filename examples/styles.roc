app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import pf.Stdout
import ansi.ANSI
import ansi.Style

## Style some text, then reset so the style does not leak into following lines.
with_style : Str, List(Style.Style) -> Str
with_style = |text, styles| Str.concat(ANSI.style(text, styles), ANSI.style("", [Default]))

main! = |_args| {
	lines = [
		with_style("Bold On", [Bold(On)]),
		with_style("Faint On", [Faint(On)]),
		with_style("Italic On", [Italic(On)]),
		with_style("Strikethrough On", [Strikethrough(On)]),
		with_style("Underline On", [Underline(On)]),
		with_style("Invert On", [Invert(On)]),
		with_style("Combination", [Bold(On), Italic(On), Strikethrough(On), Underline(On)]),
		"This should not have any style",
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
