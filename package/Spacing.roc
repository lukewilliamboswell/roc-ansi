## Helpers for horizontal and vertical whitespace.
Spacing := [Padding(Side, U64)].{
	is_eq : _
	to_hash : _

	Side := [Top, Right, Bottom, Left].{
		is_eq : _
		to_hash : _
	}

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

## Top padding prepends newlines.
expect Spacing.apply(Padding(Top, 3))("Hello") == "\n\n\nHello"

## Right padding appends spaces.
expect Spacing.apply(Padding(Right, 2))("Hello") == "Hello  "

## Bottom padding appends newlines.
expect Spacing.apply(Padding(Bottom, 3))("Hello") == "Hello\n\n\n"

## Left padding prepends spaces.
expect Spacing.apply(Padding(Left, 2))("Hello") == "  Hello"
