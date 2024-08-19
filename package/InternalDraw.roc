module [
    ScreenSize,
    Position,
    DrawFn,
    Pixel,
]

import Color exposing [Color]
import Style exposing [Style]

ScreenSize : { width : U16, height : U16 }
Position : { row : U16, col : U16 }
DrawFn : Position -> Result Pixel {}
Pixel : { char : Str, fg : Color, bg : Color, styles : List Style }
