app [target] {
	ansi: "../../package/main.roc",
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
}

import fuzz.Fuzz
import ansi.PieceTable

# Counts the allocations made by the operations a caller runs in a loop.
#
# A change that keeps a reference alive a little longer can turn an in-place
# update into a copy of a whole list on every call. The result is still
# correct and every test still passes, so the only way to notice is to count.
#
# This is a roc-fuzz target because that platform's host counts allocations.
# Nothing is fuzzed: scripts/src/Allocations.roc replays one input for each
# case in tests/allocations.json and holds the count to the ceiling recorded
# there. The first byte of an input picks the operation and the second says
# how many times to repeat it.

document : PieceTable.PieceTable(U8)
document = {
	original: Str.to_utf8("hello terminal"),
	added: [],
	table: [PieceTable.Entry.Original({ start: 0, len: 14 })],
}

## Insert one value into the middle of the document, `count` times over.
insert : PieceTable.PieceTable(U8), U64 -> PieceTable.PieceTable(U8)
insert = |table, count|
	if (count == 0) table else insert(PieceTable.insert(table, { values: ['x'], index: 5 }), count - 1)

## Delete the value in the middle of the document, `count` times over.
delete : PieceTable.PieceTable(U8), U64 -> PieceTable.PieceTable(U8)
delete = |table, count|
	if (count == 0) table else delete(PieceTable.delete(table, { index: 5 }), count - 1)

test! : List(U8) => U8
test! = |bytes| {
	count = U8.to_u64(bytes.get(1) ?? 0)
	measured = match bytes.get(0) ?? 0 {
		0 => Fuzz.measure_allocs!(|{}| insert(document, count))
		_ => {
			# Deleting needs something to delete, which is set up uncounted.
			longer = insert(document, count)
			Fuzz.measure_allocs!(|{}| delete(longer, count))
		}
	}
	# The count leaves through the only channel a target has. The harness
	# expects this crash and reads the number out of it.
	crash "ALLOCATIONS ${measured.allocations.to_str()} for a document of ${PieceTable.to_list(measured.value).len().to_str()} values"
}

target = Fuzz.from_bytes!({ name: "allocations", test! })
