module [Rgb, Hex, from_hex]

import Utils

Rgb : (U8, U8, U8)

Hex : U32

from_hex : Hex -> Rgb
from_hex = |hex|
    u24 = (Utils.clamp(0x000000, 0xFFFFFF))(hex)
    c = |a| u24 |> Num.shift_right_by(Num.mul(8, (2 - a))) |> Num.bitwise_and(0xFF) |> Num.to_u8
    (c(0), c(1), c(2))

expect from_hex(0xFF0000) == (255, 0, 0)
expect from_hex(0x00FF00) == (0, 255, 0)
expect from_hex(0x0000FF) == (0, 0, 255)
expect from_hex(0xFFFFFFFF) == (255, 255, 255)
