## Helpers for horizontal and vertical whitespace.
Spacing := [Padding(Side, U64)].{
	Side := [Top, Right, Bottom, Left]

	xw : Str
	xw = " "

	yw : Str
	yw = "\n"

	padding : Side, U64 -> Spacing
	padding = |side, width| Padding(side, width)

	apply : Spacing -> (Str -> Str)
	apply = |spacing| {
		|str|
			match spacing {
				Padding(side, width) =>
					match side {
						Top => Str.concat(Str.repeat(Spacing.yw, width), str)
						Right => Str.concat(str, Str.repeat(Spacing.xw, width))
						Bottom => Str.concat(str, Str.repeat(Spacing.yw, width))
						Left => Str.concat(Str.repeat(Spacing.xw, width), str)
					}
				}
	}
}

expect Spacing.apply(Padding(Top, 3))("Hello") == "\n\n\nHello"
expect Spacing.apply(Padding(Right, 2))("Hello") == "Hello  "
expect Spacing.apply(Padding(Bottom, 3))("Hello") == "Hello\n\n\n"
expect Spacing.apply(Padding(Left, 2))("Hello") == "  Hello"
