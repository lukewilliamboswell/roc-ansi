app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import pf.Stdout

with_color : Str, Str, Str -> Str
with_color = |text, fg, bg| "\u(001b)[${fg}m\u(001b)[${bg}m${text}\u(001b)[0m"

main! = |_args| {
	parts = [
		"The ",
		with_color("GREEN", "32", "49"),
		" frog, the ",
		with_color("BLUE", "34", "49"),
		" bird, and the ",
		with_color("RED", "31", "49"),
		" ant shared a leaf.",
	]

	Stdout.line!(Str.join_with(parts, ""))?
	Ok({})
}
