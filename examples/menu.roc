app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst",
}

import pf.Stdout
import ansi.ANSI
import ansi.Style

# Draw a menu with one highlighted entry, combining colours and styles.
#
#     roc examples/menu.roc
#
# This prints a single frame and exits: it shows how to render a selection,
# not how to read keys. An interactive program would redraw the same lines
# each time the selected index changes.

## Style some text, then reset so the style does not leak into following lines.
with_style : Str, List(Style.Style) -> Str
with_style = |text, styles| Str.concat(ANSI.style(text, styles), ANSI.style("", [Default]))

## One menu entry. The selected entry is bold and green with a `>` marker; the
## others are plain white with a `-`, so the choice reads without colour too.
menu_line : Str, Bool -> Str
menu_line = |label, selected| {
	if selected {
		# Style first, then colour: `ANSI.color` ends with a reset, which also
		# switches the bold off.
		ANSI.color(ANSI.style("> ${label}", [Bold(On)]), { fg: Standard(Green), bg: Default })
	} else {
		ANSI.color("- ${label}", { fg: Standard(White), bg: Default })
	}
}

main! = |_args| {
	lines = [
		with_style("Choose a task", [Bold(On)]),
		"",
		# To move the highlight, change which entry is passed `True`.
		menu_line("Generate report", True),
		menu_line("Sync cache", False),
		menu_line("Publish bundle", False),
		"",
		ANSI.color("ENTER to run, ESC to quit", { fg: Standard(Blue), bg: Default }),
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
