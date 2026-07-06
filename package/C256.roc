import Rgb

## [Ansi 256 colors](https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit)
## System range (0-15)
## Chromatic range 6x6x6 cube (16-231)
## Grayscale range (232-255)
C256 := U8.{
	# https://www.hackitu.de/termcolor256/
	to_rgb : U8 -> (U8, U8, U8)
	to_rgb = |color| {
		code = U8.to_u64(color)

		if code < 16 {
			match system_range.get(code) {
				Ok(rgb) => rgb
				Err(_) => (0, 0, 0)
			}
		} else if code < 232 {
			index = code - 16
			c = |a| {
				divisor = match a {
					0 => 36
					1 => 6
					_ => 1
				}

				match chromatic_range.get((index // divisor) % 6) {
					Ok(value) => value
					Err(_) => 0
				}
			}

			(c(0), c(1), c(2))
		} else {
			index = code - 232
			gray = match grayscale_range.get(index) {
				Ok(value) => value
				Err(_) => 0
			}
			(gray, gray, gray)
		}
	}
}

# https://www.ditig.com/publications/256-colors-cheat-sheet
system_range : List((U8, U8, U8))
system_range = [
	(0, 0, 0), # Standard black
	(128, 0, 0), # Standard red
	(0, 128, 0), # Standard green
	(128, 128, 0), # Standard yellow
	(0, 0, 128), # Standard blue
	(128, 0, 128), # Standard magenta
	(0, 128, 128), # Standard cyan
	(192, 192, 192), # Standard white (light gray)
	(128, 128, 128), # Bright black (dark gray)
	(255, 0, 0), # Bright red
	(0, 255, 0), # Bright green
	(255, 255, 0), # Bright yellow
	(0, 0, 255), # Bright blue
	(255, 0, 255), # Bright magenta
	(0, 255, 255), # Bright cyan
	(255, 255, 255), # Bright white
]

chromatic_range : List(U8)
chromatic_range = [0, 95, 135, 175, 215, 255]

grayscale_range : List(U8)
grayscale_range = [
	8,
	18,
	28,
	38,
	48,
	58,
	68,
	78,
	88,
	98,
	108,
	118,
	128,
	138,
	148,
	158,
	168,
	178,
	188,
	198,
	208,
	218,
	228,
	238,
]

## ANSI 256 color code 8 is bright black.
expect C256.to_rgb(8) == (128, 128, 128)

## ANSI 256 color code 55 is a purple chromatic cube entry.
expect C256.to_rgb(55) == (95, 0, 175)

## ANSI 256 color code 240 is a grayscale entry.
expect C256.to_rgb(240) == (88, 88, 88)

# TODO: toC16 : C256 -> C16
