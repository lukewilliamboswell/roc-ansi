app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Stdout
import ansi.PieceTable

# Edit text with a piece table, the structure a text editor keeps its buffer in.
#
#     roc examples/piece-table.roc
#
# A piece table never changes the text it started with. It keeps that text in
# `original`, appends everything typed since to `added`, and describes the
# current document as a list of spans into those two buffers. An insertion or
# a deletion only edits that list, so it costs the same however long the
# document is.

## The document a piece table currently describes, as text.
to_str : PieceTable.PieceTable(U8) -> Str
to_str = |table|
	match Str.from_utf8(PieceTable.to_list(table)) {
		Ok(str) => str
		Err(_) => "<invalid utf8>"
	}

main! = |_args| {
	# Start with a document that is one span covering the whole original
	# text, and nothing added yet.
	original = Str.to_utf8("hello terminal")
	table0 : PieceTable.PieceTable(U8)
	table0 = {
		original,
		added: [],
		table: [PieceTable.Entry.Original({ start: 0, len: original.len() })],
	}

	# Insert after "hello". The new bytes go into `added`, and the original
	# span is split around them. Each edit returns a new table.
	table1 = PieceTable.insert(table0, { values: Str.to_utf8(" colorful"), index: 5 })
	# Delete the first byte, which shortens the first span by one.
	table2 = PieceTable.delete(table1, { index: 0 })

	# `to_list` walks the spans and gives the document back as bytes.
	Stdout.line!("Piece table preview: ${to_str(table2)}")?
	Ok({})
}
