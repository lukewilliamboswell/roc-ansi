Rgb := (U8, U8, U8).{
	from_hex : U32 -> (U8, U8, U8)
	from_hex = |hex| {
		u24 = clamp(0x000000, 0xFFFFFF, hex)
		c = |a| {
			shift = match a {
				0 => 16
				1 => 8
				_ => 0
			}

			U32.to_u8_wrap(U32.bitwise_and(U32.shift_right_by(u24, shift), 0xFF))
		}

		(c(0), c(1), c(2))
	}
}

clamp : U32, U32, U32 -> U32
clamp = |min_value, max_value, value| value.min(max_value).max(min_value)

## Red hex values decode to red RGB channels.
expect Rgb.from_hex(0xFF0000) == (255, 0, 0)

## Green hex values decode to green RGB channels.
expect Rgb.from_hex(0x00FF00) == (0, 255, 0)

## Blue hex values decode to blue RGB channels.
expect Rgb.from_hex(0x0000FF) == (0, 0, 255)

## Out-of-range hex values clamp to white.
expect Rgb.from_hex(0xFFFFFFFF) == (255, 255, 255)
