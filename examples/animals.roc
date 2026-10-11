app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-11-7d256b9",
}

import pf.Stdout
import ansi.ANSI

main! = |_args| {
	parts = [
		"The ",
		ANSI.color("GREEN", { fg: Standard(Green), bg: Default }),
		" frog, the ",
		ANSI.color("BLUE", { fg: Standard(Blue), bg: Default }),
		" bird, and the ",
		ANSI.color("RED", { fg: Standard(Red), bg: Default }),
		" ant shared a leaf.",
	]

	Stdout.line!(Str.join_with(parts, ""))?
	Ok({})
}
