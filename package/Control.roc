import Style

## [Control](https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences)
## represents the control sequences for terminal commands.
## The provided commands are common and well-supported, though not exhaustive.
Control := [
	Screen([Size]),
	Cursor(
		[
			Position([Get, Save, Restore]),
			Display([On, Off]),

			## Move relatively by a specified number of rows up or down, or columns left or right.
			Rel([Up, Down, Left, Right], U16),

			## Move relatively by a specified number of rows next or previous and to the first column of the corresponding row.
			Row([Next, Prev], U16),

			## Move absolutely to the specified row and column.
			Abs({ row : U16, col : U16 }),

			## Move absolutely to the specified column in the current row.
			Col(U16),
		],
	),
	Erase(
		[
			Display([ToEnd, ToStart, All]),
			Line([ToEnd, ToStart, All]),
		],
	),
	Scroll([Up, Down], U16),
	Style(Style.Style),
].{
	is_eq : _
	to_hash : _

	to_code : Control -> Str
	to_code = |control|
		match control {
			Screen(screen_control) =>
				match screen_control {
					Size => "18t"
				}

			Cursor(cursor_control) =>
				match cursor_control {
					Position(state) =>
						match state {
							Get => "6n"
							Save => "s"
							Restore => "u"
						}

					Display(state) =>
						Str.concat(
							"?25",
							match state {
								On => "l"
								Off => "h"
							},
						)

					Rel(direction, number) =>
						Str.concat(
							number.to_str(),
							match direction {
								Up => "A"
								Down => "B"
								Right => "C"
								Left => "D"
							},
						)

					Row(direction, number) =>
						Str.concat(
							number.to_str(),
							match direction {
								Next => "E"
								Prev => "F"
							},
						)

					Abs({ row, col }) => Str.concat(Str.join_with([row.to_str(), col.to_str()], ";"), "H")
					Col(col) => Str.concat(col.to_str(), "G")
				}

			Erase(erase_control) =>
				match erase_control {
					Display(display) =>
						Str.concat(
							match display {
								ToEnd => "0"
								ToStart => "1"
								All => "2"
							},
							"J",
						)

					Line(line) =>
						Str.concat(
							match line {
								ToEnd => "0"
								ToStart => "1"
								All => "2"
							},
							"K",
						)
					}

			Scroll(direction, lines) =>
				Str.concat(
					lines.to_str(),
					match direction {
						Up => "S"
						Down => "T"
					},
				)

			Style(style) => Str.concat(Str.join_with(Style.to_code(style).map(|code| code.to_str()), ";"), "m")
		}
}
