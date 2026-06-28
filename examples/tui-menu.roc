app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "../package/main.roc",
}

import pf.Stdout
import ansi.ANSI
import ansi.C16
import ansi.Color
import ansi.Style

menu_line : Str, Bool -> Str
menu_line = |label, selected| {
	if selected {
		ANSI.color(
			ANSI.style("> ${label}", [Style.Bold(On), Style.Default]),
			{ fg: Color.Standard(C16.Name.Green), bg: Color.Default },
		)
	} else {
		ANSI.color("- ${label}", { fg: Color.Standard(C16.Name.White), bg: Color.Default })
	}
}

main! = |_args| {
	lines = [
		ANSI.style("Choose a task", [Style.Bold(On), Style.Default]),
		"",
		menu_line("Generate report", True),
		menu_line("Sync cache", False),
		menu_line("Publish bundle", False),
		"",
		ANSI.color("ENTER to run, ESC to quit", { fg: Color.Standard(C16.Name.Blue), bg: Color.Default }),
	]

	Stdout.line!(Str.join_with(lines, "\n"))
	Ok({})
}
