app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.9.0/C2RG1B9Caohfb8dfqrKu3Wu9TDQNq4zfixxAvLnMFVEL.tar.zst",
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

	Stdout.line!(Str.join_with(lines, "\n"))
	Ok({})
}
