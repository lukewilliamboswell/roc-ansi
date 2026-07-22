import Color

## [Style](https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters)
## represents the control sequence for terminal display attributes.
## It controls various attributes, which remain in effect until explicitly reset by a subsequent style sequence.
## The provided attributes are common and well-supported, though not exhaustive.
Style := [
	Default,
	Bold([On, Off]),
	Faint([On, Off]),
	Italic([On, Off]),
	Underline([On, Off]),
	Strikethrough([On, Off]),
	Invert([On, Off]),
	Foreground(Color.Color),
	Background(Color.Color),
].{
	is_eq : _
	to_hash : _

	to_code : Style -> List(U8)
	to_code = |style|
		match style {
			Default => [0]
			Bold(state) =>
				match state {
					On => [1]
					Off => [22]
				}

			Faint(state) =>
				match state {
					On => [2]
					Off => [22]
				}

			Italic(state) =>
				match state {
					On => [3]
					Off => [23]
				}

			Underline(state) =>
				match state {
					On => [4]
					Off => [24]
				}

			Strikethrough(state) =>
				match state {
					On => [9]
					Off => [29]
				}

			Invert(state) =>
				match state {
					On => [7]
					Off => [27]
				}

			Foreground(color) => Color.to_code(color, 30)
			Background(color) => Color.to_code(color, 40)
		}
}
