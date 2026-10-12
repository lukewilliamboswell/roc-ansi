app [target] {
	ansi: "../../package/main.roc",
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
}

import fuzz.Fuzz
import ansi.PieceTable

# Inserting one value and deleting at the same place must give the document
# back, wherever the place is and whatever the document holds.
#
#     roc build --fuzz fuzz/piece-table/main.roc --output=piece-table
#     ./piece-table run fuzz/piece-table/corpus --time=60
#
# Every pull request replays the committed corpus; see scripts/check_all.roc.

## An edit to try: a document, a place in it, and the value to insert there.
Case : { document : List(U8), index : U64, value : U8 }

## The first two bytes choose the place and the value, and the rest is the
## document, so the place lands inside, at the end of and beyond the document.
generate : List(U8) -> Case
generate = |bytes| {
	index = U8.to_u64(bytes.get(0) ?? 0)
	value = bytes.get(1) ?? 0
	{ document: bytes.drop_first(2), index, value }
}

test : Case -> Fuzz.Outcome
test = |{ document, index, value }| {
	table : PieceTable.PieceTable(U8)
	table = {
		original: document,
		added: [],
		table: [PieceTable.Entry.Original({ start: 0, len: document.len() })],
	}
	# An insertion past the end appends, so that is where the value went.
	at = index.min(document.len())
	inserted = PieceTable.insert(table, { values: [value], index })
	if PieceTable.to_list(inserted) != document.take_first(at).append(value).concat(document.drop_first(at)) {
		crash "insert did not put the value at index ${at.to_str()}"
	}
	if PieceTable.to_list(PieceTable.delete(inserted, { index: at })) != document {
		crash "delete at index ${at.to_str()} did not undo the insert there"
	}
	Fuzz.keep
}

target = Fuzz.target_with({
	name: "piece-table",
	generator: Fuzz.map(Fuzz.raw_bytes, generate),
	test,
	show: |case| "index=${case.index.to_str()} value=${case.value.to_str()} document=${Str.inspect(case.document)}",
})
