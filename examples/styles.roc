app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Stdout
import ansi.ANSI
import ansi.Style

# Text styles: bold, faint, italic, strikethrough, underline and inverted.
#
#     roc examples/styles.roc
#
# `ANSI.style` takes the text and a list of styles, and returns the text with
# the escape codes that switch them on in front of it. Unlike `ANSI.color` it
# does not switch them off again, which is what you want when several pieces
# of text share a style, and what `with_style` below handles when they do not.

## Style some text, then reset so the style does not leak into following lines.
with_style : Str, List(Style.Style) -> Str
with_style = |text, styles| Str.concat(ANSI.style(text, styles), ANSI.style("", [Default]))

main! = |_args| {
	lines = [
		# Each style is switched `On` here; `Off` turns a single style back
		# off without resetting the others.
		with_style("Bold On", [Bold(On)]),
		with_style("Faint On", [Faint(On)]),
		with_style("Italic On", [Italic(On)]),
		with_style("Strikethrough On", [Strikethrough(On)]),
		with_style("Underline On", [Underline(On)]),
		with_style("Invert On", [Invert(On)]),
		# Styles combine: list as many as the text needs.
		with_style("Combination", [Bold(On), Italic(On), Strikethrough(On), Underline(On)]),
		# Because every line above ended with a reset, this one is plain.
		"This should not have any style",
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
