app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import pf.Stdout
import ansi.ANSI
import ansi.C16
import ansi.C256
import ansi.Color
import ansi.Control
import ansi.PieceTable
import ansi.Rgb
import ansi.Spacing
import ansi.Style

main! = |_args| {
	Stdout.line!("Run `roc test examples/tests.roc` to exercise the roc-ansi package examples.")?
	Ok({})
}

## ANSI 256 color code 55 converts to its RGB triplet.
expect C256.to_rgb(55) == (95, 0, 175)

## Hex color parsing keeps the expected teal RGB channels.
expect Rgb.from_hex(0x008080) == (0, 128, 128)

## Arrow key input renders a readable description.
expect ANSI.input_to_str(ANSI.Input.Arrow(ANSI.Arrow.Up)) == "Arrow Up"

## Parsed input values support derived equality and hashing.
expect {
	input = ANSI.Input.Arrow(ANSI.Arrow.Up)

	input == ANSI.Input.Arrow(ANSI.Arrow.Up) and Set.contains(Set.single(input), input)
}

## Terminal values support derived equality and hashing through nested nominal types.
expect {
	red = Color.Color.C16(C16.C16.Standard(C16.Name.Red))
	style = Style.Style.Foreground(red)
	control = Control.Control.Style(style)
	escape = ANSI.Escape.Control(control)
	spacing = Spacing.padding(Spacing.Side.Left, 2)

	Set.contains(Set.single(escape), escape) and spacing == Spacing.padding(Spacing.Side.Left, 2) and Set.contains(Set.single(spacing), spacing)
}

base_table : PieceTable.PieceTable(U8)
base_table = {
	original: Str.to_utf8("abc"),
	added: [],
	table: [PieceTable.Entry.Original({ start: 0, len: 3 })],
}

## Inserting into a piece table preserves surrounding bytes.
expect PieceTable.to_list(PieceTable.insert(base_table, { values: Str.to_utf8("X"), index: 1 })) == Str.to_utf8("aXbc")
