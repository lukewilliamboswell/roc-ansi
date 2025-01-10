module [
    PieceTable,
    Entry,
    to_list,
    length,
    insert,
    delete,
]

## Represents a [Piece table](https://en.wikipedia.org/wiki/Piece_table) which
## is typically used to represent a text document while it is edited in a text
## editor
PieceTable a : {
    original : List a,
    added : List a,
    table : List Entry,
}

# Index into a buffer
Span : { start : U64, len : U64 }

## Represents an index into the original or add buffer
Entry : [Add Span, Original Span]

## Insert `values` into the table at a given `index`.
##
## If index is larger than current buffer, appends to end of file.
insert : PieceTable a, { values : List a, index : U64 } -> PieceTable a
insert = \{ original, added, table }, { values, index } ->

    # Append values to Added buffer
    len = List.len(values)
    new_added = List.concat(added, values)

    # New span
    span = Add({ start: (List.len(new_added)) - len, len })

    # Update entries in piece table, copy accross and split as required
    {
        original,
        added: new_added,
        table: insert_help(table, { index: Num.min(index, length(table)), span }, List.with_capacity((3 + List.len(table)))),
    }

insert_help : List Entry, { index : U64, span : Entry }, List Entry -> List Entry
insert_help = \in, { index, span }, out ->
    when in is
        [] -> out
        [Add(current), .. as rest] if index > current.len ->
            insert_help(rest, { index: index - current.len, span }, List.append(out, Add(current)))

        [Original(current), .. as rest] if index > current.len ->
            insert_help(rest, { index: index - current.len, span }, List.append(out, Original(current)))

        [Add(current), .. as rest] ->
            len_before = index
            len_after = current.len - len_before

            if len_before > 0 && len_after > 0 then
                # three spans
                new_spans = [
                    Add({ start: current.start, len: len_before }),
                    span,
                    Add({ start: current.start + len_before, len: len_after }),
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)
            else if len_before > 0 then
                # two spans
                new_spans = [
                    Add({ start: current.start, len: len_before }),
                    span,
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)
            else
                # after, two spans
                new_spans = [
                    span,
                    Add({ start: current.start + len_before, len: len_after }),
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)

        [Original(current), .. as rest] ->
            len_before = index
            len_after = current.len - len_before

            if len_before > 0 && len_after > 0 then
                # three spans
                new_spans = [
                    Original({ start: current.start, len: len_before }),
                    span,
                    Original({ start: current.start + len_before, len: len_after }),
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)
            else if len_before > 0 then
                # two spans
                new_spans = [
                    Original({ start: current.start, len: len_before }),
                    span,
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)
            else
                # after, two spans
                new_spans = [
                    span,
                    Original({ start: current.start + len_before, len: len_after }),
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)

## Calculate the total length when buffer indexes will be converted to a list
length : List Entry -> U64
length = \entries ->

    to_len : Entry -> U64
    to_len = \e ->
        when e is
            Add({ len }) -> len
            Original({ len }) -> len

    entries
    |> List.map(to_len)
    |> List.sum

## Delete the value at `index`
##
## If index is out of range this has no effect.
delete : PieceTable a, { index : U64 } -> PieceTable a
delete = \{ original, added, table }, { index } -> {
    original,
    added,
    table: delete_help(table, index, List.with_capacity((1 + List.len(table)))),
}

delete_help : List Entry, U64, List Entry -> List Entry
delete_help = \in, index, out ->
    when in is
        [] -> out
        [Add(span), .. as rest] if index >= span.len -> delete_help(rest, (index - span.len), List.append(out, Add(span)))
        [Original(span), .. as rest] if index >= span.len -> delete_help(rest, (index - span.len), List.append(out, Original(span)))
        [Add(span), .. as rest] ->
            is_start_of_span = index == 0
            is_end_of_span = index == span.len - 1

            if is_start_of_span then
                out
                |> List.concat([Add({ start: span.start + 1, len: span.len - 1 })])
                |> List.concat(rest)
            else if is_end_of_span then
                out
                |> List.concat([Add({ start: span.start, len: span.len - 1 })])
                |> List.concat(rest)
            else
                new_spans = [
                    Add({ start: span.start, len: index }),
                    Add({ start: span.start + index + 1, len: span.len - index - 1 }),
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)

        [Original(span), .. as rest] ->
            is_start_of_span = index == 0
            is_end_of_span = index == span.len - 1

            if is_start_of_span then
                out
                |> List.concat([Original({ start: span.start + 1, len: span.len - 1 })])
                |> List.concat(rest)
            else if is_end_of_span then
                out
                |> List.concat([Original({ start: span.start, len: span.len - 1 })])
                |> List.concat(rest)
            else
                new_spans = [
                    Original({ start: span.start, len: index }),
                    Original({ start: span.start + index + 1, len: span.len - index - 1 }),
                ]

                out
                |> List.concat(new_spans)
                |> List.concat(rest)

## Fuse the original and added buffers into a single list
to_list : PieceTable a -> List a
to_list = \piece -> to_list_help(piece, [])

to_list_help : PieceTable a, List a -> List a
to_list_help = \{ original, added, table }, acc ->
    when table is
        [] -> acc
        [Add(span)] -> List.concat(acc, List.sublist(added, span))
        [Original(span)] -> List.concat(acc, List.sublist(original, span))
        [Add(span), .. as rest] -> to_list_help({ original, added, table: rest }, List.concat(acc, List.sublist(added, span)))
        [Original(span), .. as rest] -> to_list_help({ original, added, table: rest }, List.concat(acc, List.sublist(original, span)))

test_original : List U8
test_original = Str.to_utf8("ipsum sit amet")

test_added : List U8
test_added = Str.to_utf8("Lorem deletedtext dolor")

test_table : PieceTable U8
test_table = {
    original: test_original,
    added: test_added,
    table: [
        Add({ start: 0, len: 6 }),
        Original({ start: 0, len: 5 }),
        Add({ start: 17, len: 6 }),
        Original({ start: 5, len: 9 }),
    ],
}

# should fuse buffers to get content
expect to_list(test_table) == Str.to_utf8("Lorem ipsum dolor sit amet")

# insert in the middle of a Add span
expect
    actual = test_table |> insert({ values: ['f', 'o', 'o'], index: 5 }) |> to_list |> Str.from_utf8
    actual == Ok("Loremfoo ipsum dolor sit amet")

# insert at the start of a Add span
expect
    actual = test_table |> insert({ values: ['f', 'o', 'o'], index: 0 }) |> to_list |> Str.from_utf8
    actual == Ok("fooLorem ipsum dolor sit amet")

# insert at the start of a Original span
expect
    actual = test_table |> insert({ values: ['f', 'o', 'o'], index: 6 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem fooipsum dolor sit amet")

# insert in the middle of a Original span
expect
    actual = test_table |> insert({ values: ['f', 'o', 'o'], index: 8 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipfoosum dolor sit amet")

# insert at start of text
expect
    actual = test_table |> insert({ values: ['f', 'o', 'o'], index: 0 }) |> to_list |> Str.from_utf8
    actual == Ok("fooLorem ipsum dolor sit amet")

# insert at end of text
expect
    actual = test_table |> insert({ values: ['f', 'o', 'o'], index: length(test_table.table) }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsum dolor sit ametfoo")

# insert nothing does nothing
expect
    actual = test_table |> insert({ values: [], index: 0 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsum dolor sit amet")

# insert at a range larger than current buffer
expect
    actual = test_table |> insert({ values: ['X'], index: 999 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsum dolor sit ametX")

# delete at start of text
expect
    actual = test_table |> delete({ index: 0 }) |> to_list |> Str.from_utf8
    actual == Ok("orem ipsum dolor sit amet")

# delete at end of text, note the index starts from zero
expect
    actual = test_table |> delete({ index: (length(test_table.table)) - 1 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsum dolor sit ame")

# delete at the end of an Add span
expect
    actual = test_table |> delete({ index: 5 }) |> to_list |> Str.from_utf8
    actual == Ok("Loremipsum dolor sit amet")

# delete at the start of a Add span
expect
    actual = test_table |> delete({ index: 11 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsumdolor sit amet")

# delete in the middle of an Add span
expect
    actual = test_table |> delete({ index: 13 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsum dlor sit amet")

# delete at the start of a Original span
expect
    actual = test_table |> delete({ index: 6 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem psum dolor sit amet")

# delete at the end of a Original span
expect
    actual = test_table |> delete({ index: 10 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsu dolor sit amet")

# delete in the middle of a Original span
expect
    actual = test_table |> delete({ index: 8 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipum dolor sit amet")

# delete out of range, does nothing
expect
    actual = test_table |> delete({ index: 9999 }) |> to_list |> Str.from_utf8
    actual == Ok("Lorem ipsum dolor sit amet")
