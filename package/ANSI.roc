# Copyright © 2023 Luke Boswell and subsequent authors
# Licensed under the Universal Permissive License (UPL), Version 1.0.
# SPDX-License-Identifier: UPL-1.0

import Color as ColorPkg
import Control as ControlPkg
import Style as StylePkg
import UnicodeGrapheme

ANSI := [].{
	# ANSI
	Escape := [
		Reset,
		Control(ControlPkg.Control),
	].{
		is_eq : _
		to_hash : _
	}

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
	style : Str, List(StylePkg.Style) -> Str
	style = |str, styles| style_help(str, styles, "")

	## Add color styles to a string and then reset to default.
	color : Str, { fg : ColorPkg.Color, bg : ColorPkg.Color } -> Str
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
	].{
		is_eq : _
		to_hash : _
	}

	Ctrl := [Space, A, B, C, D, E, F, G, H, I, J, K, L, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, BackSlash, SquareCloseBracket, Caret, Underscore].{
		is_eq : _
		to_hash : _
	}
	Action := [Escape, Enter, Space, Delete].{
		is_eq : _
		to_hash : _
	}
	Arrow := [Up, Down, Left, Right].{
		is_eq : _
		to_hash : _
	}
	Number := [N0, N1, N2, N3, N4, N5, N6, N7, N8, N9].{
		is_eq : _
		to_hash : _
	}
	Letter := [A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z].{
		is_eq : _
		to_hash : _
	}

	Input := [
		Ctrl(Ctrl),
		Action(Action),
		Arrow(Arrow),
		Symbol(Symbol),
		Number(Number),
		Upper(Letter),
		Lower(Letter),
		Unsupported(List(U8)),
	].{
		is_eq : _
		to_hash : _
	}

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

	## Terminal text-area dimensions in character cells, not pixels.
	ScreenSize : { width : U16, height : U16 }

	## Request the text-area size using the xterm window-operation query.
	## Write and flush this string without adding a newline. Not every terminal
	## supports the query; use a read deadline and a fallback size.
	screen_size_request : Str
	screen_size_request = ANSI.to_str(Control(Screen(Size)))

	## Parse one complete terminal size report, such as ESC[8;24;80t.
	## Accepts ESC[ and the single-byte CSI (0x9B). Both dimensions must be
	## decimal integers from 1 through 65535. Rejects incomplete replies,
	## trailing input, pixel reports and malformed or out-of-range dimensions.
	parse_screen_size : List(U8) -> Try(ScreenSize, [InvalidScreenSize])
	parse_screen_size = |bytes| {
		payload = match bytes {
			[27, '[', '8', ';', .. as rest] | [155, '8', ';', .. as rest] => rest
			_ => return Err(InvalidScreenSize)
		}
		text = Str.from_utf8(payload).map_err(|_| InvalidScreenSize)?
		if !text.ends_with("t") {
			return Err(InvalidScreenSize)
		}
		match Str.split_on(text.drop_suffix("t"), ";") {
			[rows, columns] => {
				height = screen_dimension(rows)?
				width = screen_dimension(columns)?
				Ok({ width, height })
			}
			_ => Err(InvalidScreenSize)
		}
	}

	## Send a size request and read its response using your platform's I/O.
	## `write!` must flush before returning; `read!` must enforce a deadline
	## for the whole query, because unsupported terminals may never reply.
	## Reads may split the response at any byte. The result's `input` contains
	## all bytes before and after the report, in order, for your input handler.
	## An empty read returns NoResponse. Invalid reports and a 4096-byte input
	## limit stop the query. Read/response errors retain all received bytes;
	## write errors occur before any input is read. Terminal mode is unchanged.
	## See the [terminal-size guide](https://lukewilliamboswell.github.io/roc-ansi/terminal-size.html)
	## for terminal support, callback contracts and fallback handling.
	query_screen_size! : { write! : Str => Try({}, write_err), read! : () => Try(List(U8), read_err) } => Try({ size : ScreenSize, input : List(U8) }, [WriteFailed(write_err), ReadFailed(read_err, List(U8)), NoResponse(List(U8)), InvalidResponse(List(U8)), InputLimitExceeded(List(U8))])
	query_screen_size! = |{ write!, read! }| {
		write!(ANSI.screen_size_request).map_err(|err| WriteFailed(err))?
		read_screen_size!(read!, [])
	}

	CursorPosition : { row : U16, col : U16 }
	Pixel : { char : Str, fg : ColorPkg.Color, bg : ColorPkg.Color, styles : List(StylePkg.Style) }
	DrawFn : CursorPosition, CursorPosition -> Try(Pixel, {})

	parse_cursor : List(U8) -> CursorPosition
	parse_cursor = |bytes| {
		{ val: row, rest: after_first } = take_number({ val: 0, rest: bytes.drop_first(2) })
		{ val: col, .. } = take_number({ val: 0, rest: after_first.drop_first(1) })

		{ row, col }
	}

	update_cursor : { cursor : CursorPosition, screen : ScreenSize }, Arrow -> { cursor : CursorPosition, screen : ScreenSize }
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
	draw_screen : { cursor : CursorPosition, screen : ScreenSize }, List(DrawFn) -> Str
	draw_screen = |{ cursor, screen }, draw_fns| {
		rows = draw_rows(cursor, screen, draw_fns, 0, List.with_capacity(U16.to_u64(screen.height)))
		join_all_pixels(rows)
	}

	draw_box : { r : U16, c : U16, w : U16, h : U16, fg : ColorPkg.Color, bg : ColorPkg.Color, char : Str, styles : List(StylePkg.Style) } -> DrawFn
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

	draw_v_line : { r : U16, c : U16, len : U16, fg : ColorPkg.Color, bg : ColorPkg.Color, char : Str, styles : List(StylePkg.Style) } -> DrawFn
	draw_v_line = |{ r, c, len, fg, bg, char, styles }| {
		|_, { row, col }|
			if col == c and (row >= r and row < (r + len)) {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
	}

	draw_h_line : { r : U16, c : U16, len : U16, fg : ColorPkg.Color, bg : ColorPkg.Color, char : Str, styles : List(StylePkg.Style) } -> DrawFn
	draw_h_line = |{ r, c, len, fg, bg, char, styles }| {
		|_, { row, col }|
			if row == r and (col >= c and col < (c + len)) {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
	}

	draw_cursor : { fg : ColorPkg.Color, bg : ColorPkg.Color, char : Str, styles : List(StylePkg.Style) } -> DrawFn
	draw_cursor = |{ fg, bg, char, styles }| {
		|cursor, { row, col }|
			if row == cursor.row and col == cursor.col {
				Ok({ char, fg, bg, styles })
			} else {
				Err({})
			}
	}

	## Draw one extended grapheme cluster per logical cell. Combining marks and
	## emoji sequences stay intact. This does not calculate terminal display
	## widths: wide characters may occupy more than one physical column.
	draw_text : Str, { r : U16, c : U16, fg : ColorPkg.Color, bg : ColorPkg.Color, styles : List(StylePkg.Style) } -> DrawFn
	draw_text = |text, { r, c, fg, bg, styles }| {
		characters = UnicodeGrapheme.slices(text)
		|_, pixel| {
			if pixel.row != r or pixel.col < c {
				return Err({})
			}
			match characters.get(U16.to_u64(pixel.col - c)) {
				Ok(char) => Ok({ char, fg, bg, styles })
				Err(_) => Err({})
			}
		}
	}
}

style_help : Str, List(StylePkg.Style), Str -> Str
style_help = |str, styles, out|
	match styles {
		[] => Str.concat(out, str)
		[style_value, .. as rest] => style_help(str, rest, Str.concat(out, style_escape(style_value)))
	}

style_escape : StylePkg.Style -> Str
style_escape = |style_value| Str.concat(Str.concat("\u(001b)[", style_code_str(StylePkg.to_code(style_value))), "m")

style_code_str : List(U8) -> Str
style_code_str = |codes| Str.join_with(style_code_parts(codes, List.with_capacity(codes.len())), ";")

style_code_parts : List(U8), List(Str) -> List(Str)
style_code_parts = |codes, out|
	match codes {
		[] => out
		[code, .. as rest] => style_code_parts(rest, out.append(code.to_str()))
	}

reset_style = "\u(001b)[0m"

## Raw arrow-up bytes parse as an up arrow input.
expect ANSI.parse_raw_stdin([27, 91, 65]) == Arrow(Up)

## A bare escape byte parses as an escape action.
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

screen_dimension = |text| {
	if text.is_empty() or !Str.to_utf8(text).all(|byte| byte >= '0' and byte <= '9') {
		return Err(InvalidScreenSize)
	}
	value = U16.from_str(text).map_err(|_| InvalidScreenSize)?
	if (value == 0) Err(InvalidScreenSize) else Ok(value)
}

read_screen_size! = |read!, buffered| {
	chunk = read!().map_err(|err| ReadFailed(err, buffered))?
	if chunk.is_empty() {
		return Err(NoResponse(buffered))
	}
	bytes = buffered.concat(chunk)
	if bytes.len() > 4096 {
		return Err(InputLimitExceeded(bytes))
	}
	match find_screen_size(bytes) {
		Found(result) => Ok(result)
		Invalid => Err(InvalidResponse(bytes))
		Pending => read_screen_size!(read!, bytes)
	}
}

# Search only for size reports; preserve every other byte for the caller.
find_screen_size = |bytes| {
	var $index = 0
	for byte in bytes {
		rest = bytes.drop_first($index)
		prefix_len = if byte == 27 and rest.take_first(4) == [27, '[', '8', ';'] {
			4
		} else if byte == 155 and rest.take_first(3) == [155, '8', ';'] {
			3
		} else {
			0
		}
		if prefix_len != 0 {
			var $length = prefix_len
			for next in rest.drop_first(prefix_len) {
				$length = $length + 1
				if next == 't' {
					return match ANSI.parse_screen_size(rest.take_first($length)) {
						Ok(size) => Found({ size, input: bytes.take_first($index).concat(rest.drop_first($length)) })
						Err(_) => Invalid
					}
				}
				if next != ';' and (next < '0' or next > '9') {
					return Invalid
				}
			}
			return Pending
		}
		$index = $index + 1
	}
	Pending
}

# Regression for #93: precomposed accents, combining marks and emoji stay intact.
expect {
	draw = ANSI.draw_text("ée\u(0301)👩‍💻x", { r: 0, c: 0, fg: Default, bg: Default, styles: [] })
	[0, 1, 2, 3].map(|col| draw({ row: 0, col: 0 }, { row: 0, col }).map_ok(|pixel| pixel.char)) == [Ok("é"), Ok("e\u(0301)"), Ok("👩‍💻"), Ok("x")]
}
expect ANSI.draw_text("", { r: 0, c: 0, fg: Default, bg: Default, styles: [] })({ row: 0, col: 0 }, { row: 0, col: 0 }) == Err({})
expect ANSI.draw_text("é", { r: 65535, c: 65535, fg: Default, bg: Default, styles: [] })({ row: 0, col: 0 }, { row: 65535, col: 65535 }).map_ok(|pixel| pixel.char) == Ok("é")

expect ANSI.screen_size_request == "\u(001b)[18t"
expect ANSI.parse_screen_size(Str.to_utf8("\u(001b)[8;24;80t")) == Ok({ width: 80, height: 24 })
expect ANSI.parse_screen_size([155].concat(Str.to_utf8("8;24;80t"))) == Ok({ width: 80, height: 24 })
expect ANSI.parse_screen_size(Str.to_utf8("\u(001b)[8;1;65535t")) == Ok({ width: 65535, height: 1 })

## Incomplete, malformed, pixel-size and out-of-range reports are rejected.
expect [
	"",
	"\u(001b)[8;24;80",
	"\u(001b)[8;24t",
	"\u(001b)[8;24;80;1t",
	"\u(001b)[4;24;80t",
	"\u(001b)[8;0;80t",
	"\u(001b)[8;24;0t",
	"\u(001b)[8;65536;80t",
	"\u(001b)[8;24;65536t",
	"\u(001b)[8;-1;80t",
	"\u(001b)[8;24;+80t",
	"\u(001b)[8;24;8_0t",
	"\u(001b)[8; 24;80t",
	"\u(001b)[8;;80t",
	"\u(001b)[8;24;t",
	"\u(001b)[8;24;80tx",
].all(|text| ANSI.parse_screen_size(Str.to_utf8(text)) == Err(InvalidScreenSize))

expect ANSI.parse_screen_size([27, '[', '8', ';', 255, ';', '8', '0', 't']) == Err(InvalidScreenSize)
expect find_screen_size(Str.to_utf8("a\u(001b)[Ab\u(001b)[8;24;80tc")) == Found({ size: { width: 80, height: 24 }, input: Str.to_utf8("a\u(001b)[Abc") })
expect find_screen_size([155].concat(Str.to_utf8("8;24;80t"))) == Found({ size: { width: 80, height: 24 }, input: [] })
expect find_screen_size(Str.to_utf8("\u(001b)[8;0;80t")) == Invalid
expect find_screen_size(Str.to_utf8("\u(001b)[8;24;x")) == Invalid
expect find_screen_size(Str.to_utf8("x\u(001b)[Ay")) == Pending

## Every proper prefix remains pending, including a split inside CSI.
screen_size_prefixes_pending = |bytes| {
	if bytes.is_empty() {
		return find_screen_size(bytes) == Pending
	}
	find_screen_size(bytes) == Pending and screen_size_prefixes_pending(bytes.drop_last(1))
}
expect screen_size_prefixes_pending(Str.to_utf8("\u(001b)[8;24;80"))
expect screen_size_prefixes_pending([155].concat(Str.to_utf8("8;24;80")))

## Cursor-position escape bytes parse row and column numbers.
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

## Number parsing leaves non-digit input untouched.
expect take_number({ val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }) == { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }

## Number parsing consumes consecutive digit bytes.
expect {
	actual = take_number({ val: 0, rest: [51, 51, 59, 49, 82] })
	actual.val == 33
		and match actual.rest {
			[59, 49, 82] => True
			_ => False
		}
}

## Number parsing stops after the final digit.
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

	Str.join_with(rows.fold_with_index(init, join_pixel_row).lines, "")
}

join_pixel_row :
	{ char : Str, fg : ColorPkg.Color, bg : ColorPkg.Color, lines : List(Str), styles : List(StylePkg.Style) }, List(ANSI.Pixel), U64 -> { char : Str, fg : ColorPkg.Color, bg : ColorPkg.Color, lines : List(Str), styles : List(StylePkg.Style) }
join_pixel_row = |{ char, fg, bg, lines, styles }, pixel_row, row| {
	folded = {
		pixel_row.fold(
			{ row_strs: List.with_capacity(pixel_row.len()), prev: { char, fg, bg, styles } },
			join_pixels,
		)
	}
	row_strs = folded.row_strs
	prev = folded.prev
	row_number = U64.to_u16_wrap(row + 1)

	line = Str.with_prefix(
		Str.join_with(row_strs, ""),
		ANSI.to_str(Control(Cursor(Abs({ row: row_number, col: 0 })))),
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

## Arrow key input renders a readable description.
expect ANSI.input_to_str(ANSI.Input.Arrow(ANSI.Arrow.Up)) == "Arrow Up"

## Coloring text wraps it in foreground and background escapes, then resets.
expect ANSI.color("green", { fg: Standard(Green), bg: Default }) == "\u(001b)[32m\u(001b)[49mgreen\u(001b)[0m"

## Parsed input values support derived equality and hashing.
expect {
	input = ANSI.Input.Arrow(ANSI.Arrow.Up)

	input == ANSI.Input.Arrow(ANSI.Arrow.Up) and Set.contains(Set.single(input), input)
}

## Escape values support derived equality and hashing through nested nominal types.
expect {
	red = ColorPkg.Color.C16(Standard(Red))
	escape = ANSI.Escape.Control(ControlPkg.Control.Style(StylePkg.Style.Foreground(red)))

	Set.contains(Set.single(escape), escape)
}
