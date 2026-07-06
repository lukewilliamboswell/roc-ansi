app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/1.0.0/AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.9.0/C2RG1B9Caohfb8dfqrKu3Wu9TDQNq4zfixxAvLnMFVEL.tar.zst",
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

main! : List(Str) => Try({}, [Exit(I32), StdoutErr(Str), ..])
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
