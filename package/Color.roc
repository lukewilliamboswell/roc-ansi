import C16
import C256
import Rgb

## [Color](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
## It includes the 4-bit, 8-bit and 24-bit colors supported on most modern terminal emulators.
Color := [
	Default,
	C16(C16.C16),
	C256(U8),
	Rgb((U8, U8, U8)),
	# Convenient to have
	Hex(Rgb.Hex),
	Standard(C16.Name),
	Bright(C16.Name),
].{
	to_code : Color, U8 -> List(U8)
	to_code = |color, offset|
		match color {
			Default => [9 + offset]
			Rgb((red, green, blue)) => [8 + offset, 2, red, green, blue]
			C256(index) => [8 + offset, 5, index]
			C16(intensity) => [
				(
					match intensity {
						Standard(name) => C16.name_to_code(name)
						Bright(name) => 60 + C16.name_to_code(name)
					},
				)
					+ offset,
			]

			Hex(hex) => Color.to_code(Rgb(Rgb.from_hex(hex)), offset)
			Standard(name) => Color.to_code(C16(Standard(name)), offset)
			Bright(name) => Color.to_code(C16(Bright(name)), offset)
		}
}
