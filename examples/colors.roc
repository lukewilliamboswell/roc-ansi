app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/1.0.0/AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.12.0/J75zfZxPJQwSG7sQJFnZHVAbJj55L3myvst2WcDWcEaZ.tar.zst",
}

import pf.Stdout

with_color : Str, Str, Str -> Str
with_color = |text, fg, bg| "\u(001b)[${fg}m\u(001b)[${bg}m${text}\u(001b)[0m"

main! : List(Str) => Try({}, [Exit(I32), StdoutErr(Str), ..])
main! = |_args| {
	lines = [
		with_color("Default color", "39", "49"),
		"ANSI 16 colors",
		with_color("Standard Red   fg", "31", "49"),
		with_color("Standard Green fg", "32", "49"),
		with_color("Standard Blue  fg", "34", "49"),
		with_color("Bright   Red   bg", "39", "101"),
		with_color("Bright   Green bg", "39", "102"),
		with_color("Bright   Blue  bg", "39", "104"),
		with_color("{ fg: Bright Red, bg: Standard Black }", "91", "40"),
		with_color("{ fg: Standard Green, bg: Standard Red }", "32", "41"),
		with_color("ANSI 256 colors", "38;5;247", "48;5;51"),
		with_color("{ fg: DarkGray, bg: Orange }", "38;5;236", "48;5;208"),
		"RGB colors, these are not supported in all terminals",
		with_color("{ fg: DarkTeal, bg: MintGreen }", "38;2;0;128;128", "48;2;152;255;152"),
		with_color("{ fg: CoralPink, bg: RoyalBlue }", "38;2;255;102;102", "48;2;65;105;225"),
		with_color("{ fg: ElectricPurple, bg: Tangerine }", "38;2;153;50;204", "48;2;255;165;0"),
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
