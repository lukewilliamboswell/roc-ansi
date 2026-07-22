app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/1.0.0/AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq.tar.zst",
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.12.0/J75zfZxPJQwSG7sQJFnZHVAbJj55L3myvst2WcDWcEaZ.tar.zst",
}

import pf.Stdout
import ansi.PieceTable

to_str : PieceTable.PieceTable(U8) -> Str
to_str = |table|
	match Str.from_utf8(PieceTable.to_list(table)) {
		Ok(str) => str
		Err(_) => "<invalid utf8>"
	}

main! : List(Str) => Try({}, [Exit(I32), StdoutErr(Str), ..])
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
