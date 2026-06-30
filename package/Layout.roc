import Spacing
import Utils

## Helpers for rendering bordered terminal grids and tables.
Layout := [].{
	LineFill(a) : { start : a, base : a, sep : a, end : a }
	RowSpacing : { mx : (U64, U64), px : (U64, U64) }
	GridSpacing : { mx : (U64, U64), my : (U64, U64), px : (U64, U64), py : (U64, U64) }

	squared_border : LineFill(LineFill(Str))
	squared_border = {
		start: { start: "┌", base: "─", sep: "┬", end: "┐" },
		base: { start: "│", base: " ", sep: "│", end: "│" },
		sep: { start: "├", base: "─", sep: "┼", end: "┤" },
		end: { start: "└", base: "─", sep: "┴", end: "┘" },
	}

	rounded_border : LineFill(LineFill(Str))
	rounded_border = {
		start: { start: "╭", base: "─", sep: "┬", end: "╮" },
		base: { start: "│", base: " ", sep: "│", end: "│" },
		sep: { start: "├", base: "─", sep: "┼", end: "┤" },
		end: { start: "╰", base: "─", sep: "┴", end: "╯" },
	}

	pretty_border : LineFill(LineFill(Str))
	pretty_border = {
		start: { start: "╭", base: "─", sep: "─", end: "╮" },
		base: { start: "│", base: " ", sep: " ", end: "│" },
		sep: { start: "│", base: "─", sep: " ", end: "│" },
		end: { start: "╰", base: "─", sep: "─", end: "╯" },
	}

	default_row_spacing : RowSpacing
	default_row_spacing = { mx: (0, 0), px: (0, 0) }

	default_spacing : GridSpacing
	default_spacing = { mx: (0, 0), my: (0, 0), px: (0, 0), py: (0, 0) }

	## Convert a flat list into row-major cells.
	data_to_rows : List(a), (U64, U64) -> Try(List(List(a)), [OutOfBounds])
	data_to_rows = |data, dimensions| data_to_rows_help(data, dimensions, 0, [])

	## Convert a flat list into column-major cells.
	data_to_columns : List(a), (U64, U64) -> Try(List(List(a)), [OutOfBounds])
	data_to_columns = |data, dimensions| data_to_columns_help(data, dimensions, 0, [])

	## Truncate or right-pad a string to exactly `size` bytes.
	trunc_or_pad : Str, Str -> (Str, U64 -> Str)
	trunc_or_pad = |trunc_char, fill_char| {
		|str, size| trunc_or_pad_help(str, size, trunc_char, fill_char)
	}

	## Draw one bordered row. `mx` is left/right margin and `px` is left/right padding.
	draw_row : List(Str), List(U64), LineFill(Str), RowSpacing -> Str
	draw_row = |data, sizes, border, spacing| {
		blocks = draw_row_blocks(data, sizes, border, spacing.px, 0, [])
		inner = Str.join_with(blocks, border.sep)

		Str.join_with(
			[
				Str.repeat("░", spacing.mx.0),
				border.start,
				inner,
				border.end,
				Str.repeat("░", spacing.mx.1),
			],
			"",
		)
	}

	## Estimate column sizes from rows, replacing length outliers with the mean.
	auto_sizes : List(List(Str)) -> List(U64)
	auto_sizes = |rows| {
		columns = rows_to_columns(rows)
		columns.map(|column| auto_size(column.map(byte_len)))
	}

	## Draw a grid with explicit border, margin, and padding settings.
	draw_grid : List(List(Str)), List(U64), LineFill(LineFill(Str)), GridSpacing -> Str
	draw_grid = |grid, sizes, border, spacing| {
		row_spacing = { mx: spacing.mx, px: spacing.px }
		padding_fill = { base: "░", sep: border.base.sep, start: border.base.start, end: border.base.end }
		margin_fill = { base: "░", sep: "░", start: "░", end: "░" }

		margin_line = Layout.draw_row([], sizes, margin_fill, row_spacing)
		top_line = Layout.draw_row([], sizes, border.start, row_spacing)
		bottom_line = Layout.draw_row([], sizes, border.end, row_spacing)
		sep_line = Layout.draw_row([], sizes, border.sep, row_spacing)
		padding_line = Layout.draw_row([], sizes, padding_fill, row_spacing)

		lines0 = List.repeat(margin_line, spacing.my.0).append(top_line)
		lines1 = draw_grid_rows(grid, sizes, border.base, sep_line, padding_line, row_spacing, spacing.py, 0, lines0)
		lines2 = lines1.append(bottom_line).concat(List.repeat(margin_line, spacing.my.1))

		Str.join_with(lines2, Spacing.yw)
	}

	## Draw a table with a header separator after the first row.
	draw_table : List(List(Str)), List(U64), LineFill(LineFill(Str)) -> Str
	draw_table = |rows, sizes, border| {
		match rows {
			[] => ""
			[head, .. as tail] => {
				top = Layout.draw_row([], sizes, border.start, Layout.default_row_spacing)
				header = Layout.draw_row(head, sizes, border.base, Layout.default_row_spacing)
				sep = Layout.draw_row([], sizes, border.sep, Layout.default_row_spacing)
				body = tail.map(|row| Layout.draw_row(row, sizes, border.base, Layout.default_row_spacing))
				bottom = Layout.draw_row([], sizes, border.end, Layout.default_row_spacing)

				Str.join_with([top, header, sep].concat(body).append(bottom), Spacing.yw)
			}
		}
	}
}

data_to_rows_help : List(a), (U64, U64), U64, List(List(a)) -> Try(List(List(a)), [OutOfBounds])
data_to_rows_help = |data, (rows, cols), row, out| {
	if row >= rows {
		Ok(out)
	} else {
		values = data_to_row(data, row, cols, 0, [])?
		data_to_rows_help(data, (rows, cols), row + 1, out.append(values))
	}
}

data_to_row : List(a), U64, U64, U64, List(a) -> Try(List(a), [OutOfBounds])
data_to_row = |data, row, cols, col, out| {
	if col >= cols {
		Ok(out)
	} else {
		match data.get(row * cols + col) {
			Ok(value) => data_to_row(data, row, cols, col + 1, out.append(value))
			Err(_) => Err(OutOfBounds)
		}
	}
}

data_to_columns_help : List(a), (U64, U64), U64, List(List(a)) -> Try(List(List(a)), [OutOfBounds])
data_to_columns_help = |data, (rows, cols), col, out| {
	if col >= cols {
		Ok(out)
	} else {
		values = data_to_column(data, rows, cols, col, 0, [])?
		data_to_columns_help(data, (rows, cols), col + 1, out.append(values))
	}
}

data_to_column : List(a), U64, U64, U64, U64, List(a) -> Try(List(a), [OutOfBounds])
data_to_column = |data, rows, cols, col, row, out| {
	if row >= rows {
		Ok(out)
	} else {
		match data.get(row * cols + col) {
			Ok(value) => data_to_column(data, rows, cols, col, row + 1, out.append(value))
			Err(_) => Err(OutOfBounds)
		}
	}
}

trunc_or_pad_help : Str, U64, Str, Str -> Str
trunc_or_pad_help = |str, size, trunc_char, fill_char| {
	if size == 0 {
		""
	} else {
		bytes = Str.to_utf8(str)
		len = bytes.len()

		if len > size {
			truncated = bytes.sublist({ start: 0, len: size - 1 })

			match Str.from_utf8(truncated) {
				Ok(prefix) => Str.concat(prefix, trunc_char)
				Err(_) => trunc_char
			}
		} else if len < size {
			Str.concat(str, Str.repeat(fill_char, size - len))
		} else {
			str
		}
	}
}

draw_row_blocks : List(Str), List(U64), Layout.LineFill(Str), (U64, U64), U64, List(Str) -> List(Str)
draw_row_blocks = |data, sizes, border, padding, index, out| {
	match sizes {
		[] => out
		[size, .. as rest] => {
			cell = match data.get(index) {
				Ok(value) => value
				Err(_) => ""
			}

			content = Layout.trunc_or_pad("…", border.base)(cell, size)
			block = Str.join_with(
				[
					Str.repeat("░", padding.0),
					content,
					Str.repeat("░", padding.1),
				],
				"",
			)

			draw_row_blocks(data, rest, border, padding, index + 1, out.append(block))
		}
	}
}

rows_to_columns : List(List(Str)) -> List(List(Str))
rows_to_columns = |rows| {
	max_width = rows.fold(0, |width, row| width.max(row.len()))
	rows_to_columns_help(rows, 0, max_width, [])
}

rows_to_columns_help : List(List(Str)), U64, U64, List(List(Str)) -> List(List(Str))
rows_to_columns_help = |rows, index, max_width, out| {
	if index >= max_width {
		out
	} else {
		column = rows_to_column(rows, index, [])
		rows_to_columns_help(rows, index + 1, max_width, out.append(column))
	}
}

rows_to_column : List(List(Str)), U64, List(Str) -> List(Str)
rows_to_column = |rows, index, out| {
	match rows {
		[] => out
		[row, .. as rest] => {
			value = match row.get(index) {
				Ok(cell) => cell
				Err(_) => ""
			}

			rows_to_column(rest, index, out.append(value))
		}
	}
}

byte_len : Str -> F64
byte_len = |str| U64.to_f64(Str.to_utf8(str).len())

auto_size : List(F64) -> U64
auto_size = |values| {
	fixed = fix_anomalies(values, 2)
	fixed.fold(0, |max_width, value| max_width.max(f64_to_u64(value)))
}

fix_anomalies : List(F64), F64 -> List(F64)
fix_anomalies = |values, k| {
	average = Utils.mean(values)
	std_dev = Utils.standard_deviation(values)
	threshold = std_dev * k

	values.map(
		|value| {
			if (value - average).abs() > threshold {
				average
			} else {
				value
			}
		},
	)
}

f64_to_u64 : F64 -> U64
f64_to_u64 = |value| {
	match F64.to_u64_try(value) {
		Ok(int) => int
		Err(_) => 0
	}
}

draw_grid_rows :
	List(List(Str)),
	List(U64),
	Layout.LineFill(Str),
	Str,
	Str,
	Layout.RowSpacing,
	(U64, U64),
	U64,
	List(Str) -> List(Str)
draw_grid_rows = |grid, sizes, border, sep_line, padding_line, row_spacing, py, index, out| {
	match grid {
		[] => out
		[row, .. as rest] => {
			with_sep = if index == 0 {
				out
			} else {
				out.append(sep_line)
			}
			with_top_padding = with_sep.concat(List.repeat(padding_line, py.0))
			with_content = with_top_padding.append(Layout.draw_row(row, sizes, border, row_spacing))
			with_bottom_padding = with_content.concat(List.repeat(padding_line, py.1))

			draw_grid_rows(rest, sizes, border, sep_line, padding_line, row_spacing, py, index + 1, with_bottom_padding)
		}
	}
}

test_data : List(Str)
test_data = [
	"ProductID",
	"ProductName",
	"Category",
	"Price",
	"StockQuantity",
	"SupplierID",
	"101",
	"Laptop",
	"Electronics",
	"1200",
	"50",
	"2001",
	"102",
	"Smartphone",
	"Electronics",
	"800",
	"150",
	"2002",
	"103",
	"Office Chair",
	"Furniture",
	"150",
	"300",
	"2003",
	"104",
	"Coffee Maker",
	"Appliances",
	"100",
	"200",
	"2004",
	"105",
	"Desk Lamp",
	"Lighting",
	"50",
	"500",
	"2005",
	"106",
	"Microwave",
	"Appliances",
	"150",
	"250",
	"2004",
]

test_rows : List(List(Str))
test_rows = [
	["ProductID", "ProductName", "Category", "Price", "StockQuantity", "SupplierID"],
	["101", "Laptop", "Electronics", "1200", "50", "2001"],
	["102", "Smartphone", "Electronics", "800", "150", "2002"],
	["103", "Office Chair", "Furniture", "150", "300", "2003"],
	["104", "Coffee Maker", "Appliances", "100", "200", "2004"],
	["105", "Desk Lamp", "Lighting", "50", "500", "2005"],
	["106", "Microwave", "Appliances", "150", "250", "2004"],
]

expect Layout.data_to_rows(test_data, (7, 6)) == Ok(test_rows)

expect Layout.data_to_columns(test_data, (7, 6)) == Ok(
	[
		["ProductID", "101", "102", "103", "104", "105", "106"],
		["ProductName", "Laptop", "Smartphone", "Office Chair", "Coffee Maker", "Desk Lamp", "Microwave"],
		["Category", "Electronics", "Electronics", "Furniture", "Appliances", "Lighting", "Appliances"],
		["Price", "1200", "800", "150", "100", "50", "150"],
		["StockQuantity", "50", "150", "300", "200", "500", "250"],
		["SupplierID", "2001", "2002", "2003", "2004", "2005", "2004"],
	],
)

expect Layout.draw_row(["ProductID", "ProductName", "Category", "Price", "StockQuantity"], [0, 1, 2, 3, 4], Layout.squared_border.base, Layout.default_row_spacing) == "││…│C…│Pr…│Sto…│"

expect Layout.draw_row([], [1, 0], Layout.squared_border.start, Layout.default_row_spacing) == "┌─┬┐"
expect Layout.draw_row([], [1, 0], Layout.rounded_border.end, Layout.default_row_spacing) == "╰─┴╯"

expect Layout.auto_sizes(test_rows) == [3, 12, 11, 5, 4, 4]

expect Layout.draw_grid([["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]], [2, 2, 2], Layout.squared_border, Layout.default_spacing) == Str.join_with(
	[
		"┌──┬──┬──┐",
		"│A…│B…│C…│",
		"├──┼──┼──┤",
		"│D…│E…│F…│",
		"└──┴──┴──┘",
	],
	"\n",
)

expect Layout.draw_grid([["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]], [2, 2, 2], Layout.squared_border, { mx: (1, 2), my: (1, 2), px: (0, 0), py: (0, 0) }) == Str.join_with(
	[
		"░░░░░░░░░░░░░",
		"░┌──┬──┬──┐░░",
		"░│A…│B…│C…│░░",
		"░├──┼──┼──┤░░",
		"░│D…│E…│F…│░░",
		"░└──┴──┴──┘░░",
		"░░░░░░░░░░░░░",
		"░░░░░░░░░░░░░",
	],
	"\n",
)

expect Layout.draw_table(test_rows, Layout.auto_sizes(test_rows), Layout.pretty_border) == Str.join_with(
	[
		"╭────────────────────────────────────────────╮",
		"│Pr… ProductName  Category    Price Sto… Sup…│",
		"│─── ──────────── ─────────── ───── ──── ────│",
		"│101 Laptop       Electronics 1200  50   2001│",
		"│102 Smartphone   Electronics 800   150  2002│",
		"│103 Office Chair Furniture   150   300  2003│",
		"│104 Coffee Maker Appliances  100   200  2004│",
		"│105 Desk Lamp    Lighting    50    500  2005│",
		"│106 Microwave    Appliances  150   250  2004│",
		"╰────────────────────────────────────────────╯",
	],
	"\n",
)
