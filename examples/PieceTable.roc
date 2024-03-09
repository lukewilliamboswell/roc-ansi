interface PieceTable
    exposes [
        PieceTable,
        PieceTableEntry,
        toList,
    ]
    imports []

## Represents a [Piece table](https://en.wikipedia.org/wiki/Piece_table) which
## is typically used to represent a text document while it is edited in a text
## editor
PieceTable a : {
    original : List a,
    added : List a,
    table : List PieceTableEntry,
}

PieceBufferIndex : { start : U64, len : U64 }

PieceTableEntry : [Add PieceBufferIndex, Original PieceBufferIndex]

toList : PieceTable a -> List a
toList = \piece ->
    takeSpans piece []

takeSpans : PieceTable a, List a -> List a
takeSpans = \{ original, added, table }, acc ->
    when table is
        [] -> acc
        [Add span] -> List.concat acc (List.sublist added span)
        [Original span] -> List.concat acc (List.sublist original span)
        [Add span, .. as rest] -> takeSpans { original, added, table: rest } (List.concat acc (List.sublist added span))
        [Original span, .. as rest] -> takeSpans { original, added, table: rest } (List.concat acc (List.sublist original span))

testOriginal : List U8
testOriginal = Str.toUtf8 "ipsum sit amet"

testAdded : List U8
testAdded = Str.toUtf8 "Lorem deletedtext dolor"

testTable : PieceTable U8
testTable = {
    original: testOriginal,
    added: testAdded,
    table: [
        Add { start: 0, len: 6 },
        Original { start: 0, len: 5 },
        Add { start: 17, len: 6 },
        Original { start: 5, len: 9 },
    ],
}

expect toList testTable == Str.toUtf8 "Lorem ipsum dolor sit amet"
