app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/1.0.0/AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.10.0/BFo7r3Lx4fuCj9ZoKagjcrkps2ceF8c1rmou1NCSos8B.tar.zst",
}

import pf.Stdout
import ansi.ANSI
import ansi.C256
import ansi.PieceTable
import ansi.Rgb

main! : List(Str) => Try({}, [Exit(I32), StdoutErr(Str), ..])
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

base_table : PieceTable.PieceTable(U8)
base_table = {
	original: Str.to_utf8("abc"),
	added: [],
	table: [PieceTable.Entry.Original({ start: 0, len: 3 })],
}

## Inserting into a piece table preserves surrounding bytes.
expect PieceTable.to_list(PieceTable.insert(base_table, { values: Str.to_utf8("X"), index: 1 })) == Str.to_utf8("aXbc")
