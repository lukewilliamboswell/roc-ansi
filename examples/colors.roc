app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-11-7d256b9",
}

import pf.Stdout
import ansi.ANSI

main! = |_args| {
	lines = [
		ANSI.color("Default color", { fg: Default, bg: Default }),
		"ANSI 16 colors",
		ANSI.color("Standard Red   fg", { fg: Standard(Red), bg: Default }),
		ANSI.color("Standard Green fg", { fg: Standard(Green), bg: Default }),
		ANSI.color("Standard Blue  fg", { fg: Standard(Blue), bg: Default }),
		ANSI.color("Bright   Red   bg", { fg: Default, bg: Bright(Red) }),
		ANSI.color("Bright   Green bg", { fg: Default, bg: Bright(Green) }),
		ANSI.color("Bright   Blue  bg", { fg: Default, bg: Bright(Blue) }),
		ANSI.color("{ fg: Bright Red, bg: Standard Black }", { fg: Bright(Red), bg: Standard(Black) }),
		ANSI.color("{ fg: Standard Green, bg: Standard Red }", { fg: Standard(Green), bg: Standard(Red) }),
		ANSI.color("ANSI 256 colors", { fg: C256(247), bg: C256(51) }),
		ANSI.color("{ fg: DarkGray, bg: Orange }", { fg: C256(236), bg: C256(208) }),
		"RGB colors, these are not supported in all terminals",
		ANSI.color("{ fg: DarkTeal, bg: MintGreen }", { fg: Hex(0x008080), bg: Hex(0x98FF98) }),
		ANSI.color("{ fg: CoralPink, bg: RoyalBlue }", { fg: Rgb((255, 102, 102)), bg: Rgb((65, 105, 225)) }),
		ANSI.color("{ fg: ElectricPurple, bg: Tangerine }", { fg: Rgb((153, 50, 204)), bg: Rgb((255, 165, 0)) }),
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
