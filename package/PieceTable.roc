## Represents a [Piece table](https://en.wikipedia.org/wiki/Piece_table) which
## is typically used to represent a text document while it is edited in a text
## editor.
PieceTable(a) := {
	original : List(a),
	added : List(a),
	table : List(Entry),
}.{
	# Index into a buffer.
	Span : { start : U64, len : U64 }

	## Represents an index into the original or added buffer.
	Entry := [Add(Span), Original(Span)]

	## Insert `values` into the table at a given `index`.
	##
	## If index is larger than current buffer, appends to end of file.
	insert : PieceTable(a), { values : List(a), index : U64 } -> PieceTable(a)
	insert = |{ original, added, table }, { values, index }| {
		len = values.len()
		new_added = added.concat(values)
		span = PieceTable.Entry.Add({ start: new_added.len() - len, len })

		{
			original,
			added: new_added,
			table: insert_help(table, { index: index.min(PieceTable.length(table)), span }, List.with_capacity(3 + table.len())),
		}
	}

	## Calculate the total length when buffer indexes will be converted to a list.
	length : List(Entry) -> U64
	length = |entries| entries.fold(0, |acc, entry| acc + entry_len(entry))

	## Delete the value at `index`.
	##
	## If index is out of range this has no effect.
	delete : PieceTable(a), { index : U64 } -> PieceTable(a)
	delete = |{ original, added, table }, { index }| {
		original,
		added,
		table: delete_help(table, index, List.with_capacity(1 + table.len())),
	}

	## Fuse the original and added buffers into a single list.
	to_list : PieceTable(a) -> List(a)
	to_list = |piece| to_list_help(piece, [])
}

entry_len : PieceTable.Entry -> U64
entry_len = |entry|
	match entry {
		PieceTable.Entry.Add(span) => span.len
		PieceTable.Entry.Original(span) => span.len
	}

insert_help : List(PieceTable.Entry), { index : U64, span : PieceTable.Entry }, List(PieceTable.Entry) -> List(PieceTable.Entry)
insert_help = |input, { index, span }, out|
	match input {
		[] => out

		[PieceTable.Entry.Add(current), .. as rest] if index > current.len =>
			insert_help(rest, { index: index - current.len, span }, out.append(PieceTable.Entry.Add(current)))

		[PieceTable.Entry.Original(current), .. as rest] if index > current.len =>
			insert_help(rest, { index: index - current.len, span }, out.append(PieceTable.Entry.Original(current)))

		[PieceTable.Entry.Add(current), .. as rest] => {
			len_before = index
			len_after = current.len - len_before

			if len_before > 0 and len_after > 0 {
				out.concat([
					PieceTable.Entry.Add({ start: current.start, len: len_before }),
					span,
					PieceTable.Entry.Add({ start: current.start + len_before, len: len_after }),
				]).concat(rest)
			} else if len_before > 0 {
				out.concat([
					PieceTable.Entry.Add({ start: current.start, len: len_before }),
					span,
				]).concat(rest)
			} else {
				out.concat([
					span,
					PieceTable.Entry.Add({ start: current.start + len_before, len: len_after }),
				]).concat(rest)
			}
		}

		[PieceTable.Entry.Original(current), .. as rest] => {
			len_before = index
			len_after = current.len - len_before

			if len_before > 0 and len_after > 0 {
				out.concat([
					PieceTable.Entry.Original({ start: current.start, len: len_before }),
					span,
					PieceTable.Entry.Original({ start: current.start + len_before, len: len_after }),
				]).concat(rest)
			} else if len_before > 0 {
				out.concat([
					PieceTable.Entry.Original({ start: current.start, len: len_before }),
					span,
				]).concat(rest)
			} else {
				out.concat([
					span,
					PieceTable.Entry.Original({ start: current.start + len_before, len: len_after }),
				]).concat(rest)
			}
		}
	}

delete_help : List(PieceTable.Entry), U64, List(PieceTable.Entry) -> List(PieceTable.Entry)
delete_help = |input, index, out|
	match input {
		[] => out
		[PieceTable.Entry.Add(span), .. as rest] if index >= span.len => delete_help(rest, index - span.len, out.append(PieceTable.Entry.Add(span)))
		[PieceTable.Entry.Original(span), .. as rest] if index >= span.len => delete_help(rest, index - span.len, out.append(PieceTable.Entry.Original(span)))
		[PieceTable.Entry.Add(span), .. as rest] => delete_from_add(span, rest, index, out)
		[PieceTable.Entry.Original(span), .. as rest] => delete_from_original(span, rest, index, out)
	}

delete_from_add : PieceTable.Span, List(PieceTable.Entry), U64, List(PieceTable.Entry) -> List(PieceTable.Entry)
delete_from_add = |span, rest, index, out| {
	is_start_of_span = index == 0
	is_end_of_span = index == span.len - 1

	if is_start_of_span {
		out.concat([PieceTable.Entry.Add({ start: span.start + 1, len: span.len - 1 })]).concat(rest)
	} else if is_end_of_span {
		out.concat([PieceTable.Entry.Add({ start: span.start, len: span.len - 1 })]).concat(rest)
	} else {
		out.concat([
			PieceTable.Entry.Add({ start: span.start, len: index }),
			PieceTable.Entry.Add({ start: span.start + index + 1, len: span.len - index - 1 }),
		]).concat(rest)
	}
}

delete_from_original : PieceTable.Span, List(PieceTable.Entry), U64, List(PieceTable.Entry) -> List(PieceTable.Entry)
delete_from_original = |span, rest, index, out| {
	is_start_of_span = index == 0
	is_end_of_span = index == span.len - 1

	if is_start_of_span {
		out.concat([PieceTable.Entry.Original({ start: span.start + 1, len: span.len - 1 })]).concat(rest)
	} else if is_end_of_span {
		out.concat([PieceTable.Entry.Original({ start: span.start, len: span.len - 1 })]).concat(rest)
	} else {
		out.concat([
			PieceTable.Entry.Original({ start: span.start, len: index }),
			PieceTable.Entry.Original({ start: span.start + index + 1, len: span.len - index - 1 }),
		]).concat(rest)
	}
}

to_list_help : PieceTable(a), List(a) -> List(a)
to_list_help = |{ original, added, table }, acc|
	match table {
		[] => acc
		[PieceTable.Entry.Add(span)] => acc.concat(added.sublist(span))
		[PieceTable.Entry.Original(span)] => acc.concat(original.sublist(span))
		[PieceTable.Entry.Add(span), .. as rest] => to_list_help({ original, added, table: rest }, acc.concat(added.sublist(span)))
		[PieceTable.Entry.Original(span), .. as rest] => to_list_help({ original, added, table: rest }, acc.concat(original.sublist(span)))
	}

test_original : List(U8)
test_original = Str.to_utf8("ipsum sit amet")

test_added : List(U8)
test_added = Str.to_utf8("Lorem deletedtext dolor")

test_table : PieceTable(U8)
test_table = {
	original: test_original,
	added: test_added,
	table: [
		PieceTable.Entry.Add({ start: 0, len: 6 }),
		PieceTable.Entry.Original({ start: 0, len: 5 }),
		PieceTable.Entry.Add({ start: 17, len: 6 }),
		PieceTable.Entry.Original({ start: 5, len: 9 }),
	],
}

table_to_str : PieceTable(U8) -> Try(Str, _)
table_to_str = |table| Str.from_utf8(PieceTable.to_list(table))

## Fusing buffers returns the visible content.
expect PieceTable.to_list(test_table) == Str.to_utf8("Lorem ipsum dolor sit amet")

## Inserting in the middle of an added span preserves both sides.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['f', 'o', 'o'], index: 5 }))?
	actual == "Loremfoo ipsum dolor sit amet"
}

## Inserting at the start of an added span prepends the new bytes.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['f', 'o', 'o'], index: 0 }))?
	actual == "fooLorem ipsum dolor sit amet"
}

## Inserting at the start of an original span keeps the original bytes after the insert.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['f', 'o', 'o'], index: 6 }))?
	actual == "Lorem fooipsum dolor sit amet"
}

## Inserting in the middle of an original span splits that span.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['f', 'o', 'o'], index: 8 }))?
	actual == "Lorem ipfoosum dolor sit amet"
}

## Inserting at the start of text prepends the new bytes.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['f', 'o', 'o'], index: 0 }))?
	actual == "fooLorem ipsum dolor sit amet"
}

## Inserting at the end of text appends the new bytes.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['f', 'o', 'o'], index: PieceTable.length(test_table.table) }))?
	actual == "Lorem ipsum dolor sit ametfoo"
}

## Inserting an empty list leaves the text unchanged.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: [], index: 0 }))?
	actual == "Lorem ipsum dolor sit amet"
}

## Inserting past the current buffer appends at the end.
expect {
	actual = table_to_str(PieceTable.insert(test_table, { values: ['X'], index: 999 }))?
	actual == "Lorem ipsum dolor sit ametX"
}

## Deleting at the start of text removes the first byte.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 0 }))?
	actual == "orem ipsum dolor sit amet"
}

## Deleting at the final zero-based index removes the last byte.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: PieceTable.length(test_table.table) - 1 }))?
	actual == "Lorem ipsum dolor sit ame"
}

## Deleting at the end of an added span joins the neighboring text.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 5 }))?
	actual == "Loremipsum dolor sit amet"
}

## Deleting at the start of an added span removes its first byte.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 11 }))?
	actual == "Lorem ipsumdolor sit amet"
}

## Deleting in the middle of an added span splits that span.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 13 }))?
	actual == "Lorem ipsum dlor sit amet"
}

## Deleting at the start of an original span removes its first byte.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 6 }))?
	actual == "Lorem psum dolor sit amet"
}

## Deleting at the end of an original span removes its final byte.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 10 }))?
	actual == "Lorem ipsu dolor sit amet"
}

## Deleting in the middle of an original span splits that span.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 8 }))?
	actual == "Lorem ipum dolor sit amet"
}

## Deleting out of range leaves the text unchanged.
expect {
	actual = table_to_str(PieceTable.delete(test_table, { index: 9999 }))?
	actual == "Lorem ipsum dolor sit amet"
}
