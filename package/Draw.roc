module [
    ScreenSize,
    CursorPosition,
    DrawFn,
    Pixel,
]

import Color exposing [Color]
import Style exposing [Style]

ScreenSize : { width : U16, height : U16 }
CursorPosition : { row : U16, col : U16 }
DrawFn : CursorPosition, CursorPosition -> Result Pixel {}
Pixel : { char : Str, fg : Color, bg : Color, styles : List Style }
