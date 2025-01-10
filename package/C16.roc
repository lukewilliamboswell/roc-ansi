module [C16, to_c256, name_to_code, Name]

import C256 exposing [C256]

## [Ansi 16 colors](https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit)
## This colors can be customized, leading to variations across different terminals.
## Therefore, if your use case requires a consistent color palette, it's recommended to avoid using them.
C16 : [Standard Name, Bright Name]
Name : [Black, Red, Green, Yellow, Blue, Magenta, Cyan, White]

name_to_code : Name -> U8
name_to_code = \name ->
    when name is
        Black -> 0
        Red -> 1
        Green -> 2
        Yellow -> 3
        Blue -> 4
        Magenta -> 5
        Cyan -> 6
        White -> 7

to_c256 : C16 -> C256
to_c256 = \intensity ->
    when intensity is
        Standard(name) -> 0 + name_to_code(name)
        Bright(name) -> 8 + name_to_code(name)
