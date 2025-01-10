module [C256, to_rgb]

import Rgb exposing [Rgb]

## [Ansi 16 colors](https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit)
## System range (0-15)
## Chromatic range 6x6x6 cube (16-231)
## Grayscale range (232-255)
C256 : U8

to_code : C256 -> U8
to_code = \color -> color

# https://www.ditig.com/publications/256-colors-cheat-sheet
system_range : List Rgb
system_range = [
    (000, 000, 000), # Standard black
    (128, 000, 000), # Standard red
    (000, 128, 000), # Standard green
    (128, 128, 000), # Standard yellow
    (000, 000, 128), # Standard blue
    (128, 000, 128), # Standard magenta
    (000, 128, 128), # Standard cyan
    (192, 192, 192), # Standard white (light gray)
    (128, 128, 128), # Bright black (dark gray)
    (255, 000, 000), # Bright red
    (000, 255, 000), # Bright green
    (255, 255, 000), # Bright yellow
    (000, 000, 255), # Bright blue
    (255, 000, 255), # Bright magenta
    (000, 255, 255), # Bright cyan
    (255, 255, 255), # Bright white
]

chromatic_range = List.concat([0], List.range({ start: At(95), end: Length(5), step: 40 }))
grayscale_range = List.range({ start: At(8), end: Length(24), step: 10 })

# https://www.hackitu.de/termcolor256/
to_rgb : C256 -> Rgb
to_rgb = \color ->
    when Num.to_u64(to_code(color)) is
        code if code < 16 ->
            List.get(system_range, code) |> Result.with_default((0, 0, 0))

        code if code < 232 ->
            index = code - 16
            c = \a -> List.get(chromatic_range, (index |> Num.div_trunc(Num.pow_int(6, (2 - a))) |> Num.rem(6))) |> Result.with_default(0)
            (c(0), c(1), c(2))

        code ->
            index = code - 232
            gray = List.get(grayscale_range, index) |> Result.with_default(0)
            (gray, gray, gray)

expect to_rgb(8) == (128, 128, 128)
expect to_rgb(55) == (95, 0, 175)
expect to_rgb(240) == (88, 88, 88)

# TODO: toC16 : C256 -> C16
