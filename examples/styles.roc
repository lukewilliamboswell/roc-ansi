app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst",
	roc: "nightly-2026-10-04-130536d",
}

import pf.Stdout

with_style : Str, Str -> Str
with_style = |text, code| "\u(001b)[${code}m${text}\u(001b)[0m"

main! = |_args| {
	lines = [
		with_style("Bold On", "1"),
		with_style("Faint On", "2"),
		with_style("Italic On", "3"),
		with_style("Strikethrough On", "9"),
		with_style("Underline On", "4"),
		with_style("Invert On", "7"),
		with_style("Combination", "1;3;9;4"),
		"This should not have any style",
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
