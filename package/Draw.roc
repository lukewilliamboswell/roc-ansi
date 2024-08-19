module [
    VirtualScreen,
    ScreenSize,
    Position,
    DrawFn,
    Pixel,
    empty,
    render,
    clear,
    draw,
    pixel,
    box,
]

import InternalDiff
import InternalDraw
import Color exposing [Color]
import Style exposing [Style]

ScreenSize : InternalDraw.ScreenSize
Position : InternalDraw.Position
DrawFn : InternalDraw.DrawFn
Pixel : InternalDraw.Pixel

VirtualScreen := {
    screen : ScreenSize,
    pixels : List Pixel,
} implements [Inspect]

empty : VirtualScreen
empty =
    @VirtualScreen {
        screen: { width : 0, height : 0 },
        pixels: [],
    }

render : ScreenSize, List DrawFn -> VirtualScreen
render = \screen, drawFns ->
    List.range { start: At 0, end: Before screen.height } |> List.map \row ->
        List.range { start: At 0, end: Before screen.width } |> List.map \col ->
            (
                List.walkUntil
                    drawFns
                    (Err {})
                    \state, drawFn ->
                        when drawFn {row, col} is
                            Ok p -> Break (Ok p)
                            Err _ -> Continue state
            )
            |> Result.withDefault { char: ",", fg: Default, bg: Standard Magenta, styles: [] }

    |> List.join
    |> \pixels -> @VirtualScreen { screen, pixels }

# old screen, new screen -> (stdout, new screen)
draw : VirtualScreen, VirtualScreen -> (Str, VirtualScreen)
draw = \@VirtualScreen old, @VirtualScreen new ->

    # (Str, List Pixel, U16, CusorRelativePosition, Color, Color, List Style)
    result = InternalDiff.diffPixels old.pixels new.pixels new.screen.width CurrentPixel Default Default []

    (result.0, @VirtualScreen new)

## Set every pixel on the screen
##
## This can be used as the last fn to provide a desired backgound
clear : { fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
clear = \{ fg ? Default, bg ? Default, char ? " ", styles ? [] } -> \_ ->
    Ok { char, fg, bg, styles }

pixel : Position, { fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
pixel = \position, { fg ? Default, bg ? Default, char ? " ", styles ? [] } -> \{ row, col } ->
        if (row == position.row) && (col == position.col) then
            Ok { char, fg, bg, styles }
        else
            Err {}

box : { r : U16, c : U16, w : U16, h : U16, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
box = \{ r, c, w, h, fg ? Default, bg ? Default, char ? "#", styles ? [] } -> \{ row, col } ->

        startRow = r
        endRow = (r + h)
        startCol = c
        endCol = (c + w)

        if row == r && (col >= startCol && col < endCol) then
            Ok { char, fg, bg, styles } # TOP BORDER
        else if row == (r + h - 1) && (col >= startCol && col < endCol) then
            Ok { char, fg, bg, styles } # BOTTOM BORDER
        else if col == c && (row >= startRow && row < endRow) then
            Ok { char, fg, bg, styles } # LEFT BORDER
        else if col == (c + w - 1) && (row >= startRow && row < endRow) then
            Ok { char, fg, bg, styles } # RIGHT BORDER
        else
            Err {}
