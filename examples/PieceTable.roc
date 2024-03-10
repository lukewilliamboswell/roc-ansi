interface PieceTable
    exposes [
        PieceTable,
        PieceTableEntry,
        toList,
        length,
        insert,
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

## Represents an index into the original or add buffer
PieceTableEntry : [Add PieceBufferIndex, Original PieceBufferIndex]

insert : PieceTable a, { values : List a, index : U64 } -> PieceTable a
insert = \{ original, added, table }, { values, index } ->

    # Append values to Added buffer
    len = List.len values
    newAdded = List.concat added values

    # New span
    span = Add { start: (List.len newAdded) - len, len }

    # Update entries in piece table, copy accross and split as required
    {
        original,
        added: newAdded,
        table: insertHelp table { index, span } (List.withCapacity (3 + List.len table)),
    }

insertHelp : List PieceTableEntry, { index : U64, span : PieceTableEntry }, List PieceTableEntry -> List PieceTableEntry
insertHelp = \in, { index, span }, out ->
    when in is
        [] -> out
        [Add current, .. as rest] if index > current.len ->
            insertHelp rest { index: index - current.len, span } (List.append out (Add current))

        [Original current, .. as rest] if index > current.len ->
            insertHelp rest { index: index - current.len, span } (List.append out (Original current))

        [Add current, .. as rest] ->
            lenBefore = index
            lenAfter = current.len - lenBefore

            if lenBefore > 0 && lenAfter > 0 then
                # three spans
                out
                |> List.concat [
                    Add { start: current.start, len: lenBefore },
                    span,
                    Add { start: current.start + lenBefore, len: lenAfter },
                ]
                |> List.concat rest
            else if lenBefore > 0 then
                # two spans
                out
                |> List.concat [
                    Add { start: current.start, len: lenBefore },
                    span,
                ]
                |> List.concat rest
            else if lenAfter > 0 then
                # two spans
                out
                |> List.concat [
                    span,
                    Add { start: current.start + lenBefore, len: lenAfter },
                ]
                |> List.concat rest
            else
                crash "unreachable"

        [Original current, .. as rest] ->
            lenBefore = index
            lenAfter = current.len - lenBefore

            if lenBefore > 0 && lenAfter > 0 then
                # three spans
                out
                |> List.concat [
                    Original { start: current.start, len: lenBefore },
                    span,
                    Original { start: current.start + lenBefore, len: lenAfter },
                ]
                |> List.concat rest
            else if lenBefore > 0 then
                # two spans
                out
                |> List.concat [
                    Original { start: current.start, len: lenBefore },
                    span,
                ]
                |> List.concat rest
            else if lenAfter > 0 then
                # two spans
                out
                |> List.concat [
                    span,
                    Original { start: current.start + lenBefore, len: lenAfter },
                ]
                |> List.concat rest
            else
                crash "unreachable"

## Fuse the original and added buffers into a single list
toList : PieceTable a -> List a
toList = \piece ->
    takeSpans piece []

## Calculate the total length when buffer indexes will be converted to a list
length : List PieceTableEntry -> U64
length = \entries ->
    entries
    |> List.map \e ->
        when e is
            Add { len } -> len
            Original { len } -> len
    |> List.sum

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

# should fuse buffers to get content
expect toList testTable == Str.toUtf8 "Lorem ipsum dolor sit amet"

# insert in the middle of a Add span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 5 } |> toList |> Str.fromUtf8
    actual == Ok "Loremfoo ipsum dolor sit amet"

# insert at the start of a Add span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "fooLorem ipsum dolor sit amet"

# insert at the start of a Original span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 6 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem fooipsum dolor sit amet"

# insert in the middle of a Original span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 8 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipfoosum dolor sit amet"

# insert at start of text
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "fooLorem ipsum dolor sit amet"

# insert at end of text
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: length testTable.table } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit ametfoo"

# insert nothing does nothing
expect
    actual = testTable |> insert { values: [], index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit amet"
