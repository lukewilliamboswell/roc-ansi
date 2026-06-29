app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "../package/main.roc",
}

import pf.Stdout
import ansi.ANSI
import ansi.C16
import ansi.C256
import ansi.Color
import ansi.Layout
import ansi.PieceTable
import ansi.Rgb
import ansi.Spacing

main! = |_args| {
	Stdout.line!("Run `roc test examples/tests.roc` to exercise the roc-ansi package examples.")
	Ok({})
}

expect C256.to_rgb(55) == (95, 0, 175)

expect Rgb.from_hex(0x008080) == (0, 128, 128)

expect ANSI.input_to_str(ANSI.Input.Arrow(ANSI.Arrow.Up)) == "Arrow Up"

expect ANSI.color("green", { fg: Color.Standard(C16.Name.Green), bg: Color.Default }) == "\u(001b)[32m\u(001b)[49mgreen\u(001b)[0m"

base_table : PieceTable.PieceTable(U8)
base_table = {
	original: Str.to_utf8("abc"),
	added: [],
	table: [PieceTable.Entry.Original({ start: 0, len: 3 })],
}

expect PieceTable.to_list(PieceTable.insert(base_table, { values: Str.to_utf8("X"), index: 1 })) == Str.to_utf8("aXbc")

expect Spacing.apply(Spacing.Padding(Spacing.Side.Left, 2))("Hi") == "  Hi"

expect Layout.draw_grid([["A", "B"], ["C", "D"]], [1, 1], Layout.squared_border, Layout.default_spacing) == Str.join_with(
	[
		"┌─┬─┐",
		"│A│B│",
		"├─┼─┤",
		"│C│D│",
		"└─┴─┘",
	],
	"\n",
)
