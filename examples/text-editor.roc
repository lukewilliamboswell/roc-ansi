app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import pf.Stdout
import ansi.PieceTable

to_str : PieceTable.PieceTable(U8) -> Str
to_str = |table|
	match Str.from_utf8(PieceTable.to_list(table)) {
		Ok(str) => str
		Err(_) => "<invalid utf8>"
	}

main! = |_args| {
	original = Str.to_utf8("hello terminal")
	table0 : PieceTable.PieceTable(U8)
	table0 = {
		original,
		added: [],
		table: [PieceTable.Entry.Original({ start: 0, len: original.len() })],
	}

	table1 = PieceTable.insert(table0, { values: Str.to_utf8(" colorful"), index: 5 })
	table2 = PieceTable.delete(table1, { index: 0 })

	Stdout.line!("Piece table preview: ${to_str(table2)}")?
	Ok({})
}
