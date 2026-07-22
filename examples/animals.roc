app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/1.0.0/AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.12.0/J75zfZxPJQwSG7sQJFnZHVAbJj55L3myvst2WcDWcEaZ.tar.zst",
}

import pf.Stdout

with_color : Str, Str, Str -> Str
with_color = |text, fg, bg| "\u(001b)[${fg}m\u(001b)[${bg}m${text}\u(001b)[0m"

main! : List(Str) => Try({}, [Exit(I32), StdoutErr(Str), ..])
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
