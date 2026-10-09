app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import pf.Stdout

with_style : Str, Str -> Str
with_style = |text, code| "\u(001b)[${code}m${text}\u(001b)[0m"

with_color : Str, Str, Str -> Str
with_color = |text, fg, bg| "\u(001b)[${fg}m\u(001b)[${bg}m${text}\u(001b)[0m"

menu_line : Str, Bool -> Str
menu_line = |label, selected| {
	if selected {
		with_color(with_style("> ${label}", "1"), "32", "49")
	} else {
		with_color("- ${label}", "37", "49")
	}
}

main! = |_args| {
	lines = [
		with_style("Choose a task", "1"),
		"",
		menu_line("Generate report", True),
		menu_line("Sync cache", False),
		menu_line("Publish bundle", False),
		"",
		with_color("ENTER to run, ESC to quit", "34", "49"),
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
