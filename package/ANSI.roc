import Color as ColorPkg
import Control as ControlPkg
import Style as StylePkg

ANSI := [].{
	# ANSI
	Color : ColorPkg.Color
	Style : StylePkg.Style
	Control : ControlPkg.Control

	Escape := [
		Reset,
		Control(ControlPkg.Control),
	]

	to_str : Escape -> Str
	to_str = |escape|
		Str.concat(
			"\u(001b)",
			match escape {
				Reset => "c"
				Control(control) => Str.concat("[", ControlPkg.to_code(control))
			},
		)

	## Add styles to a string.
	style : Str, List(Style) -> Str
	style = |str, styles| {
		codes = styles.map(|style_value| ANSI.to_str(Control(Style(style_value))))
		Str.join_with(codes.append(str), "")
	}

	## Add color styles to a string and then reset to default.
	color : Str, { fg : Color, bg : Color } -> Str
	color = |str, { fg, bg }| {
		styled = ANSI.style(str, [Foreground(fg), Background(bg)])
		Str.concat(styled, reset_style)
	}

	# TUI input
	Symbol := [
		ExclamationMark,
		QuotationMark,
		NumberSign,
		DollarSign,
		PercentSign,
		Ampersand,
		Apostrophe,
		RoundOpenBracket,
		RoundCloseBracket,
		Asterisk,
		PlusSign,
		Comma,
		Hyphen,
		FullStop,
		ForwardSlash,
		Colon,
		SemiColon,
		LessThanSign,
		EqualsSign,
		GreaterThanSign,
		QuestionMark,
		AtSign,
		SquareOpenBracket,
		Backslash,
		SquareCloseBracket,
		Caret,
		Underscore,
		GraveAccent,
		CurlyOpenBrace,
		VerticalBar,
		CurlyCloseBrace,
		Tilde,
	]

	Ctrl := [Space, A, B, C, D, E, F, G, H, I, J, K, L, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, BackSlash, SquareCloseBracket, Caret, Underscore]
	Action := [Escape, Enter, Space, Delete]
	Arrow := [Up, Down, Left, Right]
	Number := [N0, N1, N2, N3, N4, N5, N6, N7, N8, N9]
	Letter := [A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z]

	Input := [
		Ctrl(Ctrl),
		Action(Action),
		Arrow(Arrow),
		Symbol(Symbol),
		Number(Number),
		Upper(Letter),
		Lower(Letter),
		Unsupported(List(U8)),
	]

	parse_raw_stdin : List(U8) -> Input
	parse_raw_stdin = |bytes|
		match bytes {
			[0, ..] => Ctrl(Space)
			[1, ..] => Ctrl(A)
			[2, ..] => Ctrl(B)
			[3, ..] => Ctrl(C)
			[4, ..] => Ctrl(D)
			[5, ..] => Ctrl(E)
			[6, ..] => Ctrl(F)
			[7, ..] => Ctrl(G)
			[8, ..] => Ctrl(H)
			[9, ..] => Ctrl(I)
			[10, ..] => Ctrl(J)
			[11, ..] => Ctrl(K)
			[12, ..] => Ctrl(L)
			[13, ..] => Action(Enter)
			[14, ..] => Ctrl(N)
			[15, ..] => Ctrl(O)
			[16, ..] => Ctrl(P)
			[17, ..] => Ctrl(Q)
			[18, ..] => Ctrl(R)
			[19, ..] => Ctrl(S)
			[20, ..] => Ctrl(T)
			[21, ..] => Ctrl(U)
			[22, ..] => Ctrl(V)
			[23, ..] => Ctrl(W)
			[24, ..] => Ctrl(X)
			[25, ..] => Ctrl(Y)
			[26, ..] => Ctrl(Z)
			[27, 91, 'A', ..] => Arrow(Up)
			[27, 91, 'B', ..] => Arrow(Down)
			[27, 91, 'C', ..] => Arrow(Right)
			[27, 91, 'D', ..] => Arrow(Left)
			[27, ..] => Action(Escape)
			[28, ..] => Ctrl(BackSlash)
			[29, ..] => Ctrl(SquareCloseBracket)
			[30, ..] => Ctrl(Caret)
			[31, ..] => Ctrl(Underscore)
			[32, ..] => Action(Space)
			['!', ..] => Symbol(ExclamationMark)
			['"', ..] => Symbol(QuotationMark)
			['#', ..] => Symbol(NumberSign)
			['$', ..] => Symbol(DollarSign)
			['%', ..] => Symbol(PercentSign)
			['&', ..] => Symbol(Ampersand)
			['\'', ..] => Symbol(Apostrophe)
			['(', ..] => Symbol(RoundOpenBracket)
			[')', ..] => Symbol(RoundCloseBracket)
			['*', ..] => Symbol(Asterisk)
			['+', ..] => Symbol(PlusSign)
			[',', ..] => Symbol(Comma)
			['-', ..] => Symbol(Hyphen)
			['.', ..] => Symbol(FullStop)
			['/', ..] => Symbol(ForwardSlash)
			['0', ..] => Number(N0)
			['1', ..] => Number(N1)
			['2', ..] => Number(N2)
			['3', ..] => Number(N3)
			['4', ..] => Number(N4)
			['5', ..] => Number(N5)
			['6', ..] => Number(N6)
			['7', ..] => Number(N7)
			['8', ..] => Number(N8)
			['9', ..] => Number(N9)
			[':', ..] => Symbol(Colon)
			[';', ..] => Symbol(SemiColon)
			['<', ..] => Symbol(LessThanSign)
			['=', ..] => Symbol(EqualsSign)
			['>', ..] => Symbol(GreaterThanSign)
			['?', ..] => Symbol(QuestionMark)
			['@', ..] => Symbol(AtSign)
			['A', ..] => Upper(A)
			['B', ..] => Upper(B)
			['C', ..] => Upper(C)
			['D', ..] => Upper(D)
			['E', ..] => Upper(E)
			['F', ..] => Upper(F)
			['G', ..] => Upper(G)
			['H', ..] => Upper(H)
			['I', ..] => Upper(I)
			['J', ..] => Upper(J)
			['K', ..] => Upper(K)
			['L', ..] => Upper(L)
			['M', ..] => Upper(M)
			['N', ..] => Upper(N)
			['O', ..] => Upper(O)
			['P', ..] => Upper(P)
			['Q', ..] => Upper(Q)
			['R', ..] => Upper(R)
			['S', ..] => Upper(S)
			['T', ..] => Upper(T)
			['U', ..] => Upper(U)
			['V', ..] => Upper(V)
			['W', ..] => Upper(W)
			['X', ..] => Upper(X)
			['Y', ..] => Upper(Y)
			['Z', ..] => Upper(Z)
			['[', ..] => Symbol(SquareOpenBracket)
			['\\', ..] => Symbol(Backslash)
			[']', ..] => Symbol(SquareCloseBracket)
			['^', ..] => Symbol(Caret)
			['_', ..] => Symbol(Underscore)
			['`', ..] => Symbol(GraveAccent)
			['a', ..] => Lower(A)
			['b', ..] => Lower(B)
			['c', ..] => Lower(C)
			['d', ..] => Lower(D)
			['e', ..] => Lower(E)
			['f', ..] => Lower(F)
			['g', ..] => Lower(G)
			['h', ..] => Lower(H)
			['i', ..] => Lower(I)
			['j', ..] => Lower(J)
			['k', ..] => Lower(K)
			['l', ..] => Lower(L)
			['m', ..] => Lower(M)
			['n', ..] => Lower(N)
			['o', ..] => Lower(O)
			['p', ..] => Lower(P)
			['q', ..] => Lower(Q)
			['r', ..] => Lower(R)
			['s', ..] => Lower(S)
			['t', ..] => Lower(T)
			['u', ..] => Lower(U)
			['v', ..] => Lower(V)
			['w', ..] => Lower(W)
			['x', ..] => Lower(X)
			['y', ..] => Lower(Y)
			['z', ..] => Lower(Z)
			['{', ..] => Symbol(CurlyOpenBrace)
			['|', ..] => Symbol(VerticalBar)
			['}', ..] => Symbol(CurlyCloseBrace)
			['~', ..] => Symbol(Tilde)
			[127, ..] => Action(Delete)
			_ => Unsupported(bytes)
		}

	input_to_str : Input -> Str
	input_to_str = |input|
		match input {
			Ctrl(key) => Str.concat("Ctrl - ", ctrl_to_str(key))
			Action(key) => Str.concat("Action ", action_to_str(key))
			Arrow(key) => Str.concat("Arrow ", arrow_to_str(key))
			Symbol(key) => Str.concat("Symbol ", ANSI.symbol_to_str(key))
			Number(key) => Str.concat("Number ", number_to_str(key))
			Upper(key) => Str.concat("Letter ", ANSI.upper_to_str(key))
			Lower(key) => Str.concat("Letter ", ANSI.lower_to_str(key))
			Unsupported(bytes) => {
				bytes_str = Str.join_with(bytes.map(|byte| byte.to_str()), ",")
				"Unsupported [${bytes_str}]"
			}
		}

	symbol_to_str : Symbol -> Str
	symbol_to_str = |symbol|
		match symbol {
			ExclamationMark => "!"
			QuotationMark => "\""
			NumberSign => "#"
			DollarSign => "\$"
			PercentSign => "%"
			Ampersand => "&"
			Apostrophe => "'"
			RoundOpenBracket => "("
			RoundCloseBracket => ")"
			Asterisk => "*"
			PlusSign => "+"
			Comma => ","
			Hyphen => "-"
			FullStop => "."
			ForwardSlash => "/"
			Colon => ":"
			SemiColon => ";"
			LessThanSign => "<"
			EqualsSign => "="
			GreaterThanSign => ">"
			QuestionMark => "?"
			AtSign => "@"
			SquareOpenBracket => "["
			Backslash => "\\"
			SquareCloseBracket => "]"
			Caret => "^"
			Underscore => "_"
			GraveAccent => "`"
			CurlyOpenBrace => "{"
			VerticalBar => "|"
			CurlyCloseBrace => "}"
			Tilde => "~"
		}

	upper_to_str : Letter -> Str
	upper_to_str = |letter|
		match letter {
			A => "A"
			B => "B"
			C => "C"
			D => "D"
			E => "E"
			F => "F"
			G => "G"
			H => "H"
			I => "I"
			J => "J"
			K => "K"
			L => "L"
			M => "M"
			N => "N"
			O => "O"
			P => "P"
			Q => "Q"
			R => "R"
			S => "S"
			T => "T"
			U => "U"
			V => "V"
			W => "W"
			X => "X"
			Y => "Y"
			Z => "Z"
		}

	lower_to_str : Letter -> Str
	lower_to_str = |letter|
		match letter {
			A => "a"
			B => "b"
			C => "c"
			D => "d"
			E => "e"
			F => "f"
			G => "g"
			H => "h"
			I => "i"
			J => "j"
			K => "k"
			L => "l"
			M => "m"
			N => "n"
			O => "o"
			P => "p"
			Q => "q"
			R => "r"
			S => "s"
			T => "t"
			U => "u"
			V => "v"
			W => "w"
			X => "x"
			Y => "y"
			Z => "z"
		}

	ScreenSize : { width : U16, height : U16 }
	CursorPosition : { row : U16, col : U16 }
	Pixel : { char : Str, fg : Color, bg : Color, styles : List(Style) }
	DrawFn : CursorPosition, CursorPosition -> Try(Pixel, {})

	parse_cursor : List(U8) -> CursorPosition
	parse_cursor = |bytes| {
		{ val: row, rest: after_first } = take_number({ val: 0, rest: List.drop_first(bytes, 2) })
		{ val: col, .. } = take_number({ val: 0, rest: List.drop_first(after_first, 1) })

		{ row, col }
	}

	update_cursor = |state, direction|
		match direction {
			Up =>
				{
					..state,
					cursor: {
						row: (state.cursor.row + state.screen.height - 1) % state.screen.height,
						col: state.cursor.col,
					},
				}

			Down =>
				{
					..state,
					cursor: {
						row: (state.cursor.row + 1) % state.screen.height,
						col: state.cursor.col,
					},
				}

			Left =>
				{
					..state,
					cursor: {
						row: state.cursor.row,
						col: (state.cursor.col + state.screen.width - 1) % state.screen.width,
					},
				}

			Right =>
				{
					..state,
					cursor: {
						row: state.cursor.row,
						col: (state.cursor.col + 1) % state.screen.width,
					},
				}
			}

	## Loop through each pixel in the screen and build up a single string to write to stdout.
	draw_screen = |{ cursor, screen }, draw_fns| {
		rows = draw_rows(cursor, screen, draw_fns, 0, List.with_capacity(U16.to_u64(screen.height)))
		join_all_pixels(rows)
	}

	draw_box : { r : U16, c : U16, w : U16, h : U16, fg : Color, bg : Color, char : Str, styles : List(Style) } -> DrawFn
	draw_box = |{ r, c, w, h, fg, bg, char, styles }| {
		|_, { row, col }| {
			start_row = r
			end_row = r + h
			start_col = c
			end_col = c + w

			if row == r and (col >= start_col and col < end_col) {
				Ok({ char, fg, bg, styles })
			} else if row == (r + h - 1) and (col >= start_col and col < end_col) {
				Ok({ char, fg, bg, styles })
			} else if col == c and (row >= start_row and row < end_row) {
				Ok({ char, fg, bg, styles })
			} else if col == (c + w - 1) and (row >= start_row and row < end_row) {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
		}
	}

	draw_v_line : { r : U16, c : U16, len : U16, fg : Color, bg : Color, char : Str, styles : List(Style) } -> DrawFn
	draw_v_line = |{ r, c, len, fg, bg, char, styles }| {
		|_, { row, col }|
			if col == c and (row >= r and row < (r + len)) {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
	}

	draw_h_line : { r : U16, c : U16, len : U16, fg : Color, bg : Color, char : Str, styles : List(Style) } -> DrawFn
	draw_h_line = |{ r, c, len, fg, bg, char, styles }| {
		|_, { row, col }|
			if row == r and (col >= c and col < (c + len)) {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
	}

	draw_cursor : { fg : Color, bg : Color, char : Str, styles : List(Style) } -> DrawFn
	draw_cursor = |{ fg, bg, char, styles }| {
		|cursor, { row, col }|
			if row == cursor.row and col == cursor.col {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
	}

	draw_text : Str, { r : U16, c : U16, fg : Color, bg : Color, styles : List(Style) } -> DrawFn
	draw_text = |text, { r, c, fg, bg, styles }| {
		|_, pixel| {
			bytes = Str.to_utf8(text)
			len = U64.to_u16_wrap(bytes.len())

			if pixel.row == r and pixel.col >= c and pixel.col < (c + len) {
				match bytes.get(U16.to_u64(pixel.col - c)) {
					Ok(byte) =>
						match Str.from_utf8([byte]) {
							Ok(char) => Ok({ char, fg, bg, styles })
							Err(_) => Err({})
						}

					Err(_) => Err({})
				}
			} else {
				Err({})
			}
		}
	}
}

reset_style : Str
reset_style = ANSI.style("", [Default])

expect ANSI.parse_raw_stdin([27, 91, 65]) == Arrow(Up)
expect ANSI.parse_raw_stdin([27]) == Action(Escape)

ctrl_to_str : ANSI.Ctrl -> Str
ctrl_to_str = |ctrl|
	match ctrl {
		A => "A"
		B => "B"
		C => "C"
		D => "D"
		E => "E"
		F => "F"
		G => "G"
		H => "H"
		I => "I"
		J => "J"
		K => "K"
		L => "L"
		N => "N"
		O => "O"
		P => "P"
		Q => "Q"
		R => "R"
		S => "S"
		T => "T"
		U => "U"
		V => "V"
		W => "W"
		X => "X"
		Y => "Y"
		Z => "Z"
		Space => "[Space]"
		BackSlash => "\\"
		SquareCloseBracket => "]"
		Caret => "^"
		Underscore => "_"
	}

action_to_str : ANSI.Action -> Str
action_to_str = |action|
	match action {
		Escape => "Escape"
		Enter => "Enter"
		Space => "Space"
		Delete => "Delete"
	}

arrow_to_str : ANSI.Arrow -> Str
arrow_to_str = |arrow|
	match arrow {
		Up => "Up"
		Down => "Down"
		Left => "Left"
		Right => "Right"
	}

number_to_str : ANSI.Number -> Str
number_to_str = |number|
	match number {
		N0 => "0"
		N1 => "1"
		N2 => "2"
		N3 => "3"
		N4 => "4"
		N5 => "5"
		N6 => "6"
		N7 => "7"
		N8 => "8"
		N9 => "9"
	}

expect ANSI.parse_cursor([27, 91, 51, 51, 59, 49, 82]) == { row: 33, col: 1 }

draw_rows : ANSI.CursorPosition, ANSI.ScreenSize, List(ANSI.DrawFn), U16, List(List(ANSI.Pixel)) -> List(List(ANSI.Pixel))
draw_rows = |cursor, screen, draw_fns, row, rows| {
	if row >= screen.height {
		rows
	} else {
		pixel_row = draw_cols(cursor, draw_fns, row, 0, screen.width, List.with_capacity(U16.to_u64(screen.width)))
		draw_rows(cursor, screen, draw_fns, row + 1, rows.append(pixel_row))
	}
}

draw_cols : ANSI.CursorPosition, List(ANSI.DrawFn), U16, U16, U16, List(ANSI.Pixel) -> List(ANSI.Pixel)
draw_cols = |cursor, draw_fns, row, col, width, pixels| {
	if col >= width {
		pixels
	} else {
		pixel = {
			draw_fns.fold_until(
				{ char: " ", fg: Default, bg: Default, styles: [] },
				|default_pixel, draw_fn|
					match draw_fn(cursor, { row, col }) {
						Ok(draw_pixel) => Break(draw_pixel)
						Err(_) => Continue(default_pixel)
					},
			)
		}

		draw_cols(cursor, draw_fns, row, col + 1, width, pixels.append(pixel))
	}
}

take_number : { val : U16, rest : List(U8) } -> { val : U16, rest : List(U8) }
take_number = |input|
	match input.rest {
		[digit, .. as rest] if digit >= '0' and digit <= '9' => {
			value = input.val * 10 + U8.to_u16(digit - '0')
			take_number({ val: value, rest })
		}

		_ => input
	}

expect take_number({ val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }) == { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }
expect take_number({ val: 0, rest: [51, 51, 59, 49, 82] }) == { val: 33, rest: [59, 49, 82] }
expect take_number({ val: 0, rest: [49, 82] }) == { val: 1, rest: [82] }

join_all_pixels : List(List(ANSI.Pixel)) -> Str
join_all_pixels = |rows| {
	init = {
		char: " ",
		fg: Default,
		bg: Default,
		lines: List.with_capacity(rows.len()),
		styles: [],
	}

	Str.join_with(List.fold_with_index(rows, init, join_pixel_row).lines, "")
}

join_pixel_row :
	{ char : Str, fg : ANSI.Color, bg : ANSI.Color, lines : List(Str), styles : List(ANSI.Style) },
	List(ANSI.Pixel),
	U64 -> { char : Str, fg : ANSI.Color, bg : ANSI.Color, lines : List(Str), styles : List(ANSI.Style) }
join_pixel_row = |{ char, fg, bg, lines, styles }, pixel_row, row| {
	folded = {
		pixel_row.fold(
			{ row_strs: List.with_capacity(pixel_row.len()), prev: { char, fg, bg, styles } },
			join_pixels,
		)
	}
	row_strs = folded.row_strs
	prev = folded.prev

	line = Str.with_prefix(
		Str.join_with(row_strs, ""),
		ANSI.to_str(Control(Cursor(Abs({ row: U64.to_u16_wrap(row + 1), col: 0 })))),
	)

	{ char: " ", fg: prev.fg, bg: prev.bg, lines: lines.append(line), styles: prev.styles }
}

join_pixels : { row_strs : List(Str), prev : ANSI.Pixel }, ANSI.Pixel -> { row_strs : List(Str), prev : ANSI.Pixel }
join_pixels = |{ row_strs, prev }, curr| {
	fg_str = {
		if curr.fg != prev.fg {
			Str.concat(ANSI.to_str(Control(Style(Foreground(curr.fg)))), curr.char)
		} else {
			curr.char
		}
	}

	pixel_str = {
		if curr.bg != prev.bg {
			Str.concat(ANSI.to_str(Control(Style(Background(curr.bg)))), fg_str)
		} else {
			fg_str
		}
	}

	{ row_strs: row_strs.append(pixel_str), prev: curr }
}
