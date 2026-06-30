app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.9.0/C2RG1B9Caohfb8dfqrKu3Wu9TDQNq4zfixxAvLnMFVEL.tar.zst",
}

import pf.Stdout
import ansi.ANSI
import ansi.C256
import ansi.PieceTable
import ansi.Rgb

main! = |_args| {
	Stdout.line!("Run `roc test examples/tests.roc` to exercise the roc-ansi package examples.")
	Ok({})
}

expect C256.to_rgb(55) == (95, 0, 175)

expect Rgb.from_hex(0x008080) == (0, 128, 128)

expect ANSI.input_to_str(ANSI.Input.Arrow(ANSI.Arrow.Up)) == "Arrow Up"

base_table : PieceTable.PieceTable(U8)
base_table = {
	original: Str.to_utf8("abc"),
	added: [],
	table: [PieceTable.Entry.Original({ start: 0, len: 3 })],
}

expect PieceTable.to_list(PieceTable.insert(base_table, { values: Str.to_utf8("X"), index: 1 })) == Str.to_utf8("aXbc")
