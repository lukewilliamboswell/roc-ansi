app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Stdout
import ansi.ANSI

# Every way of naming a colour, from the most portable to the least.
#
#     roc examples/colors.roc
#
# A colour is one of four things: the terminal's `Default`, one of the 16 named
# ANSI colours, an index into the 256-colour palette, or a 24-bit RGB value.
# Which to use depends on how much you care about the exact shade and how old
# a terminal you need to support.
main! = |_args| {
	lines = [
		# `Default` means "whatever the terminal is configured with".
		ANSI.color("Default color", { fg: Default, bg: Default }),
		"ANSI 16 colors",
		# The 16 named colours work everywhere, but each terminal theme picks
		# its own shade for them. `Standard` and `Bright` are the two
		# intensities of the same eight names.
		ANSI.color("Standard Red   fg", { fg: Standard(Red), bg: Default }),
		ANSI.color("Standard Green fg", { fg: Standard(Green), bg: Default }),
		ANSI.color("Standard Blue  fg", { fg: Standard(Blue), bg: Default }),
		# The foreground and the background are set independently.
		ANSI.color("Bright   Red   bg", { fg: Default, bg: Bright(Red) }),
		ANSI.color("Bright   Green bg", { fg: Default, bg: Bright(Green) }),
		ANSI.color("Bright   Blue  bg", { fg: Default, bg: Bright(Blue) }),
		ANSI.color("{ fg: Bright Red, bg: Standard Black }", { fg: Bright(Red), bg: Standard(Black) }),
		ANSI.color("{ fg: Standard Green, bg: Standard Red }", { fg: Standard(Green), bg: Standard(Red) }),
		# `C256` indexes the 256-colour palette, whose shades are fixed: use it
		# when the result should look the same in every theme.
		ANSI.color("ANSI 256 colors", { fg: C256(247), bg: C256(51) }),
		ANSI.color("{ fg: DarkGray, bg: Orange }", { fg: C256(236), bg: C256(208) }),
		"RGB colors, these are not supported in all terminals",
		# `Hex` and `Rgb` give an exact 24-bit colour, written whichever way
		# is handier. Older terminals ignore or approximate them.
		ANSI.color("{ fg: DarkTeal, bg: MintGreen }", { fg: Hex(0x008080), bg: Hex(0x98FF98) }),
		ANSI.color("{ fg: CoralPink, bg: RoyalBlue }", { fg: Rgb((255, 102, 102)), bg: Rgb((65, 105, 225)) }),
		ANSI.color("{ fg: ElectricPurple, bg: Tangerine }", { fg: Rgb((153, 50, 204)), bg: Rgb((255, 165, 0)) }),
	]

	Stdout.line!(Str.join_with(lines, "\n"))?
	Ok({})
}
