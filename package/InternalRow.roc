module []

import Draw exposing [Pixel]
import Color exposing [Color]
import Style exposing [Style]

# TODO be sure to use an ESC[0m to reset all attributes once before drawing screen

# TODO check if it is better to diff all the pixels in one go, or to instead chunk into rows or something
diffPixels : List Pixel, List Pixel, U16, CusorRelativePosition, Color, Color, List Style -> (Str, List Pixel, U16, CusorRelativePosition, Color, Color, List Style)
diffPixels = \oldPixels, newPixels, screenWidth, cursor, currentFg, currentBg, currentStyles ->

    # TODO -- check if it is worth having this check here, does this just introduce a deep check
    # for equality, when it may be just as fast to loop through and check each pixel one at a time
    if oldPixels == newPixels then

        # move the cursor relative offset to the next row
        # skip drawing anything for this row on the screen
        updatedCursor = updateCursorRelative cursor (Row screenWidth)

        ("", newPixels, screenWidth, updatedCursor, currentFg, currentBg, currentStyles)

    else
        # walk the pixels and diff them
        List.walkWithIndex newPixels ("", newPixels, screenWidth, cursor, currentFg, currentBg, currentStyles) (diffPixelsHelp oldPixels)

diffPixelsHelp : List Pixel -> ((Str, List Pixel, U16, CusorRelativePosition, Color, Color, List Style), Pixel, U64 -> (Str, List Pixel, U16, CusorRelativePosition, Color, Color, List Style))
diffPixelsHelp = \oldPixels -> \(buf, newPixels, screenWidth, cursor, currentFg, currentBg, currentStyles), newPixel, idx ->
    oldPixel =
        List.get oldPixels idx
        # new screen larger than old screen use a default pixel for diffing
        |> Result.withDefault { char : " ", fg : Default, bg : Default, styles : [] }

    (_, updatedCursor, updatedFg, updatedBg, updatedStyles, pixelStr) = diffPixel oldPixel newPixel screenWidth cursor currentFg currentBg currentStyles

    ("$(buf)$(pixelStr)", newPixels, screenWidth, updatedCursor, updatedFg, updatedBg, updatedStyles)

# no changes, just the cursor offset should be updated
expect
    result = diffPixels [] [] 100 CurrentPixel Default Default []
    result.3 == PrevPixel 100

# no changes, just the cursor offset should be updated
expect
    result = diffPixels [] [] 100 (PrevPixel 23) Default Default []
    result.3 == PrevPixel 123

# changes should include updates to color
expect
    oldPixels = [
        { char : "f", fg : Default, bg : Default, styles : [] },
        { char : "o", fg : Default, bg : Default, styles : [] },
        { char : "o", fg : Default, bg : Default, styles : [] },
    ]
    newPixels = [
        { char : "B", fg : Standard Blue, bg : Standard White, styles : [] },
        { char : "A", fg : Standard Blue, bg : Standard White, styles : [] },
        { char : "R", fg : Standard Blue, bg : Standard White, styles : [] },
    ]
    result = diffPixels oldPixels newPixels 100 CurrentPixel Default Default []

    result.0 == "\u(001b)[34m\u(001b)[47mBAR"

# should ONLY include 1 cursor position and update to color and the new changes
# here we expect to change the second row, so cursor shift 1 row down
expect
    oldPixels = [
        { char : "f", fg : Default, bg : Default, styles : [] },
        { char : "o", fg : Default, bg : Default, styles : [] },
        { char : "o", fg : Default, bg : Default, styles : [] },
        { char : "b", fg : Default, bg : Default, styles : [] },
        { char : "a", fg : Default, bg : Default, styles : [] },
        { char : "r", fg : Default, bg : Default, styles : [] },
    ]
    newPixels = [
        { char : "f", fg : Default, bg : Default, styles : [] },
        { char : "o", fg : Default, bg : Default, styles : [] },
        { char : "o", fg : Default, bg : Default, styles : [] },
        { char : "B", fg : Standard Blue, bg : Standard White, styles : [] },
        { char : "A", fg : Standard Blue, bg : Standard White, styles : [] },
        { char : "R", fg : Standard Blue, bg : Standard White, styles : [] },
    ]
    result = diffPixels oldPixels newPixels 3 CurrentPixel Default Default []

    result.0 == "\u(001b)[1B\u(001b)[34m\u(001b)[47mBAR"

# Keep track of how many pixels behind current is from
# the cursor. This is relative, so if there is no
# change we don't need to include an ANSI command
# to move the cursor before drawing
CusorRelativePosition : [PrevPixel U16, CurrentPixel]

updateCursorRelative : CusorRelativePosition, [NoDraw, Draw, Row U16] -> CusorRelativePosition
updateCursorRelative = \cursor, update ->
    when (cursor, update) is
        (PrevPixel n, NoDraw) -> PrevPixel (n+1)
        (CurrentPixel, NoDraw) -> PrevPixel 1
        (PrevPixel _, Draw) -> CurrentPixel
        (CurrentPixel, Draw) -> CurrentPixel
        (PrevPixel n, Row r) -> PrevPixel (n+r)
        (CurrentPixel, Row r) -> PrevPixel r

diffPixel : Pixel, Pixel, U16, CusorRelativePosition, Color, Color, List Style -> (Pixel, CusorRelativePosition, Color, Color, List Style, Str)
diffPixel = \old, new, screenWidth, cursor, currentFg, currentBg, currentStyles ->
    if old == new then
        (new, updateCursorRelative cursor NoDraw, currentFg, currentBg, currentStyles, "")
    else
        # set cursor?
        (buf0, updatedCursor) = updateCursorOnDraw screenWidth cursor

        # set foreground color?
        # note we are using currentFg here as we don't care about the old value, but what was
        # last drawn to the screen
        (buf1, updatedFg) = updateColorOnDraw buf0 Foreground currentFg new.fg

        # set background color?
        # note we are using currentBg here as we don't care about the old value, but what was
        # last drawn to the screen
        (buf2, updatedBg) = updateColorOnDraw buf1 Background currentBg new.bg

        # set styles?
        # TODO -- lets just leave this for later...

        # return the pixel, updated values and buffer
        (new, updatedCursor, updatedFg, updatedBg, currentStyles, "$(buf2)$(new.char)")

# note we are using the current color here as we don't care about the old/previous value,
# but what was the last drawn to the screen, as that is what will be continued unless we
# change it.
updateColorOnDraw : Str, [Foreground, Background], Color, Color -> (Str, Color)
updateColorOnDraw = \buf, type, current, new ->

    offset = when type is
        Foreground -> 30
        Background -> 40

    if current == new then
        # no change from last drawn, leave as it was
        (buf, new)
    else
        # different from last drawn, update to the new color
        str = new |> Color.toCode offset |> List.map Num.toStr |> Str.joinWith ";" |> Str.concat "m"
        ("$(buf)\u(001b)[$(str)", new)

# no change
expect updateColorOnDraw "" Foreground Default Default == ("", Default)

# changed
expect updateColorOnDraw "..." Foreground Default (Standard Green) == ("...\u(001b)[32m", Standard Green)

# we have a new pixel, we know there is a difference
# so we need to move the cursor so the following draws will
# be in the correct position on the screen
updateCursorOnDraw : U16, CusorRelativePosition -> (Str, CusorRelativePosition)
updateCursorOnDraw = \screenWidth, cursor ->
    when cursor is

        # cursor doesn't need to move, it's already on the current pixel
        CurrentPixel -> ("", updateCursorRelative cursor Draw)

        # cursor needs to move > 1 cols Right and possible > 1 rows Down
        PrevPixel n ->
            rowsBehind = n // screenWidth
            colsBehind = n % screenWidth

            if rowsBehind > 0 && colsBehind > 0 then
                # move cursor relative down by rows and right by cols
                ("\u(001b)[$(Num.toStr rowsBehind)B\u(001b)[$(Num.toStr colsBehind)D", updateCursorRelative cursor Draw)
            else if rowsBehind > 0 then
                # move cursor relative down by rows, cols is 0
                ("\u(001b)[$(Num.toStr rowsBehind)B", updateCursorRelative cursor Draw)
            else
                # move cursor relative just right by cols
                ("\u(001b)[$(Num.toStr colsBehind)D", updateCursorRelative cursor Draw)

# cursor at current pixel
expect updateCursorOnDraw 3 CurrentPixel == ("", CurrentPixel)

# cursor 1 row and 1 col behind current pixel
expect updateCursorOnDraw 3 (PrevPixel 4) == ("\u(001b)[1B\u(001b)[1D", CurrentPixel)

# cursor 0 row and 2 col behind current pixel
expect updateCursorOnDraw 3 (PrevPixel 2) == ("\u(001b)[2D", CurrentPixel)

# no change, should just update cursor relative position
expect
    old = { char : "A", fg : Default, bg : Default, styles : [] }
    new = { char : "A", fg : Default, bg : Default, styles : [] }
    screenWidth = 100u16
    cursor = CurrentPixel
    currentFg = Default
    currentBg = Default
    currentStyles = []

    result = diffPixel old new screenWidth cursor currentFg currentBg currentStyles

    result.1 == PrevPixel 1

# no change, should just update cursor relative position
expect
    old = { char : "A", fg : Default, bg : Default, styles : [] }
    new = { char : "A", fg : Default, bg : Default, styles : [] }
    screenWidth = 100u16
    cursor = PrevPixel 34
    currentFg = Default
    currentBg = Default
    currentStyles = []

    result = diffPixel old new screenWidth cursor currentFg currentBg currentStyles

    result.1 == PrevPixel 35

# changed char, should update cursor position
expect
    old = { char : "A", fg : Default, bg : Default, styles : [] }
    new = { char : "B", fg : Default, bg : Default, styles : [] }
    screenWidth = 100u16
    cursor = PrevPixel 5
    currentFg = Default
    currentBg = Default
    currentStyles = []

    result = diffPixel old new screenWidth cursor currentFg currentBg currentStyles

    result.5 == "\u(001b)[5DB"

# changed char, fg, and bg should update cursor position down 1 row, right 5 cols
# colors different from previous, but the same as current
expect
    old = { char : "A", fg : Default, bg : Default, styles : [] }
    new = { char : "🇦🇺", fg : Standard White, bg : Standard Blue, styles : [] }
    screenWidth = 100u16
    cursor = PrevPixel 105
    currentFg = Standard White
    currentBg = Standard Blue
    currentStyles = []

    result = diffPixel old new screenWidth cursor currentFg currentBg currentStyles

    result.5 == "\u(001b)[1B\u(001b)[5D🇦🇺"

# changed char, fg, and bg should update cursor position down 1 row, right 5 cols
# colors different from both and current
expect
    old = { char : "A", fg : Standard Black, bg : Standard Red, styles : [] }
    new = { char : "🇦🇺", fg : Standard White, bg : Standard Blue, styles : [] }
    screenWidth = 100u16
    cursor = PrevPixel 105
    currentFg = Standard Green
    currentBg = Standard Yellow
    currentStyles = []

    result = diffPixel old new screenWidth cursor currentFg currentBg currentStyles

    result.5 == "\u(001b)[1B\u(001b)[5D\u(001b)[37m\u(001b)[44m🇦🇺"
