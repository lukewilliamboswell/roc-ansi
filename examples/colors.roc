app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "../package/main.roc",
}

import pf.Stdout
import ansi.ANSI
import ansi.C16
import ansi.Color

main! = |_args| {
	lines = [
		ANSI.color("Default color", { fg: Color.Default, bg: Color.Default }),
		"ANSI 16 colors",
		ANSI.color("Standard Red   fg", { fg: Color.Standard(C16.Name.Red), bg: Color.Default }),
		ANSI.color("Standard Green fg", { fg: Color.Standard(C16.Name.Green), bg: Color.Default }),
		ANSI.color("Standard Blue  fg", { fg: Color.Standard(C16.Name.Blue), bg: Color.Default }),
		ANSI.color("Bright   Red   bg", { fg: Color.Default, bg: Color.Bright(C16.Name.Red) }),
		ANSI.color("Bright   Green bg", { fg: Color.Default, bg: Color.Bright(C16.Name.Green) }),
		ANSI.color("Bright   Blue  bg", { fg: Color.Default, bg: Color.Bright(C16.Name.Blue) }),
		ANSI.color("{ fg: Bright Red, bg: Standard Black }", { fg: Color.Bright(C16.Name.Red), bg: Color.Standard(C16.Name.Black) }),
		ANSI.color("{ fg: Standard Green, bg: Standard Red }", { fg: Color.Standard(C16.Name.Green), bg: Color.Standard(C16.Name.Red) }),
		ANSI.color("ANSI 256 colors", { fg: Color.C256(247), bg: Color.C256(51) }),
		ANSI.color("{ fg: DarkGray, bg: Orange }", { fg: Color.C256(236), bg: Color.C256(208) }),
		"RGB colors, these are not supported in all terminals",
		ANSI.color("{ fg: DarkTeal, bg: MintGreen }", { fg: Color.Hex(0x008080), bg: Color.Hex(0x98FF98) }),
		ANSI.color("{ fg: CoralPink, bg: RoyalBlue }", { fg: Color.Rgb((255, 102, 102)), bg: Color.Rgb((65, 105, 225)) }),
		ANSI.color("{ fg: ElectricPurple, bg: Tangerine }", { fg: Color.Rgb((153, 50, 204)), bg: Color.Rgb((255, 165, 0)) }),
	]

	Stdout.line!(Str.join_with(lines, "\n"))
	Ok({})
}
