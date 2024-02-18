interface Core
    exposes [
        # ANSI
        Escape,
        Control,
        toStr,

        # Style
        Style,
        withStyle,

        # Color
        Color,
        withFg,
        withBg,
        withColor,

        # TUI
        DrawFn,
        Pixel,
        ScreenSize,
        Position,
        Input,
        parseCursor,
        updateCursor,
        inputToStr,
        parseRawStdin,
        drawScreen,
        drawText,
        drawVLine,
        drawHLine,
        drawBox,
        drawCursor,
    ]
    imports []

## [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)

Escape : [
    Reset,
    Control Control,
]

Control : [
    MoveCursor
        [
            Step [Up, Down, Left, Right] I32,
            Line [Next, Prev] I32,
            To { row : I32, col : I32 },
            Home,
        ],
    Erase [Display [ToEnd, ToStart, All], Line [ToEnd, ToStart, All]],
    ClearScreen,
    GetCursor,
    Scroll [Up, Down] I32,
    Style Style,
]

Style : [
    Default,
    Bold [On, Off],
    Faint [On, Off],
    Italic [On, Off],
    Underline [On, Off],
    Overline [On, Off], # TODO: Investigate which terminals support this
    Strikethrough [On, Off],
    Blink [Slow, Rapid, Off], # TODO: Investigate which terminals support rapid blink
    Invert [On, Off],
    Foreground Color,
    Background Color,
]

## 4-bit, 8-bit and 24-bit colors supported on *most* modern terminal emulators
Color : [
    Default,
    Standard [Black, Red, Green, Yellow, Blue, Magenta, Cyan, White],
    # For terminals which support axiterm specification
    Bright [Black, Red, Green, Yellow, Blue, Magenta, Cyan, White],
    B8 U8,
    B24 (U8, U8, U8),
]

toStr = \x -> "\u(001b)$(fromEscape x)"

fromEscape : Escape -> Str
fromEscape = \escape ->
    when escape is
        Reset -> "c"
        Control control -> "[$(fromControl control)"

fromControl : Control -> Str
fromControl = \control ->
    when control is
        GetCursor -> "6n"
        MoveCursor x ->
            when x is
                Step direction steps ->
                    when direction is
                        Up -> "$(Num.toStr steps)A"
                        Down -> "$(Num.toStr steps)B"
                        Right -> "$(Num.toStr steps)C"
                        Left -> "$(Num.toStr steps)D"

                Line direction lines ->
                    when direction is
                        Next -> "$(Num.toStr lines)E"
                        Prev -> "$(Num.toStr lines)F"

                To { row, col } -> "$(Num.toStr row);$(Num.toStr col)H"
                Home -> "H"

        Erase x ->
            when x is
                Display d ->
                    when d is
                        ToEnd -> "0J"
                        ToStart -> "1J"
                        All -> "2J"

                Line l ->
                    when l is
                        ToEnd -> "0K"
                        ToStart -> "1K"
                        All -> "2K"

        ClearScreen -> "3J"
        Scroll direction lines ->
            when direction is
                Up -> "$(Num.toStr lines)S"
                Down -> "$(Num.toStr lines)T"

        Style style -> "$(style |> fromStyle |> List.map Num.toStr |> Str.joinWith ";")m"

fromStyle : Style -> List U8
fromStyle = \style ->
    when style is
        Default -> [0]
        Bold b ->
            when b is
                On -> [1]
                Off -> [22]

        Faint f ->
            when f is
                On -> [2]
                Off -> [22]

        Italic i ->
            when i is
                On -> [3]
                Off -> [23]

        Underline u ->
            when u is
                On -> [4]
                Off -> [24]

        Overline u ->
            when u is
                On -> [53]
                Off -> [55]

        Strikethrough s ->
            when s is
                On -> [9]
                Off -> [29]

        Blink b ->
            when b is
                Slow -> [5]
                Rapid -> [6]
                Off -> [25]

        Invert i ->
            when i is
                On -> [7]
                Off -> [27]

        Foreground fg -> fromFgColor fg
        Background bg -> fromBgColor bg

fromFgColor : Color -> List U8
fromFgColor = \fg ->
    when fg is
        Default -> [39]
        Standard standard ->
            when standard is
                Black -> [30]
                Red -> [31]
                Green -> [32]
                Yellow -> [33]
                Blue -> [34]
                Magenta -> [35]
                Cyan -> [36]
                White -> [37]

        Bright bright ->
            when bright is
                Black -> [90]
                Red -> [91]
                Green -> [92]
                Yellow -> [93]
                Blue -> [94]
                Magenta -> [95]
                Cyan -> [96]
                White -> [97]

        B8 b8 -> [38, 5, b8]
        B24 (r, g, b) -> [38, 2, r, g, b]

fromBgColor = \bg ->
    when bg is
        Default -> [49]
        Standard standard ->
            when standard is
                Black -> [40]
                Red -> [41]
                Green -> [42]
                Yellow -> [43]
                Blue -> [44]
                Magenta -> [45]
                Cyan -> [46]
                White -> [47]

        Bright bright ->
            when bright is
                Black -> [100]
                Red -> [101]
                Green -> [102]
                Yellow -> [103]
                Blue -> [104]
                Magenta -> [105]
                Cyan -> [106]
                White -> [107]

        B8 b8 -> [48, 5, b8]
        B24 (r, g, b) -> [48, 2, r, g, b]

## Adds style to a Str
withStyle : Str, List Style -> Str
withStyle = \str, styles ->
    styles
    |> List.map Style
    |> List.map Control
    |> List.map toStr
    |> List.append str
    |> Str.joinWith ("")

resetStyle = toStr (Control (Style (Default)))

## Adds foreground color formatting to a Str and then resets to Default
withFg : Str, Color -> Str
withFg = \str, color -> "$(toStr (Control (Style (Foreground color))))$(str)$(resetStyle)"

## Adds background color formatting to a Str and then resets to Default
withBg : Str, Color -> Str
withBg = \str, color -> "$(toStr (Control (Style (Background color))))$(str)$(resetStyle)"

## Adds color formatting to a Str and then resets to Default
withColor : Str, { fg : Color, bg : Color } -> Str
withColor = \str, colors -> "$(toStr (Control (Style (Foreground colors.fg))))$(toStr (Control (Style (Background colors.bg))))$(str)$(resetStyle)"

Key : [
    Up,
    Down,
    Left,
    Right,
    Escape,
    Enter,
    LowerA,
    UpperA,
    UpperB,
    LowerB,
    UpperC,
    LowerC,
    UpperD,
    LowerD,
    UpperE,
    LowerE,
    UpperF,
    LowerF,
    UpperG,
    LowerG,
    UpperH,
    LowerH,
    UpperI,
    LowerI,
    UpperJ,
    LowerJ,
    UpperK,
    LowerK,
    UpperL,
    LowerL,
    UpperM,
    LowerM,
    UpperN,
    LowerN,
    UpperO,
    LowerO,
    UpperP,
    LowerP,
    UpperQ,
    LowerQ,
    UpperR,
    LowerR,
    UpperS,
    LowerS,
    UpperT,
    LowerT,
    UpperU,
    LowerU,
    UpperV,
    LowerV,
    UpperW,
    LowerW,
    UpperX,
    LowerX,
    UpperY,
    LowerY,
    UpperZ,
    LowerZ,
    Space,
    ExclamationMark,
    QuotationMark,
    NumberSign,
    DollarSign,
    PercentSign,
    Ampersand,
    Apostrophe,
    RoundOpenBracket,
    RoundCloseBracket,
    Asterisk,
    PlusSign,
    Comma,
    Hyphen,
    FullStop,
    ForwardSlash,
    Colon,
    SemiColon,
    LessThanSign,
    EqualsSign,
    GreaterThanSign,
    QuestionMark,
    AtSign,
    SquareOpenBracket,
    Backslash,
    SquareCloseBracket,
    Caret,
    Underscore,
    GraveAccent,
    CurlyOpenBrace,
    VerticalBar,
    CurlyCloseBrace,
    Tilde,
    Number0,
    Number1,
    Number2,
    Number3,
    Number4,
    Number5,
    Number6,
    Number7,
    Number8,
    Number9,
]

Input : [
    KeyPress Key,
    CtrlC,
    Unsupported (List U8),
]

parseRawStdin : List U8 -> Input
parseRawStdin = \bytes ->
    when bytes is
        [27, 91, 'A', ..] -> KeyPress Up
        [27, 91, 'B', ..] -> KeyPress Down
        [27, 91, 'C', ..] -> KeyPress Right
        [27, 91, 'D', ..] -> KeyPress Left
        [27, ..] -> KeyPress Escape
        [13, ..] -> KeyPress Enter
        [32, ..] -> KeyPress Space
        ['A', ..] -> KeyPress UpperA
        ['a', ..] -> KeyPress LowerA
        ['B', ..] -> KeyPress UpperB
        ['b', ..] -> KeyPress LowerB
        ['C', ..] -> KeyPress UpperC
        ['c', ..] -> KeyPress LowerC
        ['D', ..] -> KeyPress UpperD
        ['d', ..] -> KeyPress LowerD
        ['E', ..] -> KeyPress UpperE
        ['e', ..] -> KeyPress LowerE
        ['F', ..] -> KeyPress UpperF
        ['f', ..] -> KeyPress LowerF
        ['G', ..] -> KeyPress UpperG
        ['g', ..] -> KeyPress LowerG
        ['H', ..] -> KeyPress UpperH
        ['h', ..] -> KeyPress LowerH
        ['I', ..] -> KeyPress UpperI
        ['i', ..] -> KeyPress LowerI
        ['J', ..] -> KeyPress UpperJ
        ['j', ..] -> KeyPress LowerJ
        ['K', ..] -> KeyPress UpperK
        ['k', ..] -> KeyPress LowerK
        ['L', ..] -> KeyPress UpperL
        ['l', ..] -> KeyPress LowerL
        ['M', ..] -> KeyPress UpperM
        ['m', ..] -> KeyPress LowerM
        ['N', ..] -> KeyPress UpperN
        ['n', ..] -> KeyPress LowerN
        ['O', ..] -> KeyPress UpperO
        ['o', ..] -> KeyPress LowerO
        ['P', ..] -> KeyPress UpperP
        ['p', ..] -> KeyPress LowerP
        ['Q', ..] -> KeyPress UpperQ
        ['q', ..] -> KeyPress LowerQ
        ['R', ..] -> KeyPress UpperR
        ['r', ..] -> KeyPress LowerR
        ['S', ..] -> KeyPress UpperS
        ['s', ..] -> KeyPress LowerS
        ['T', ..] -> KeyPress UpperT
        ['t', ..] -> KeyPress LowerT
        ['U', ..] -> KeyPress UpperU
        ['u', ..] -> KeyPress LowerU
        ['V', ..] -> KeyPress UpperV
        ['v', ..] -> KeyPress LowerV
        ['W', ..] -> KeyPress UpperW
        ['w', ..] -> KeyPress LowerW
        ['X', ..] -> KeyPress UpperX
        ['x', ..] -> KeyPress LowerX
        ['Y', ..] -> KeyPress UpperY
        ['y', ..] -> KeyPress LowerY
        ['Z', ..] -> KeyPress UpperZ
        ['z', ..] -> KeyPress LowerZ
        ['!', ..] -> KeyPress ExclamationMark
        ['"', ..] -> KeyPress QuotationMark
        ['#', ..] -> KeyPress NumberSign
        ['$', ..] -> KeyPress DollarSign
        ['%', ..] -> KeyPress PercentSign
        ['&', ..] -> KeyPress Ampersand
        ['\'', ..] -> KeyPress Apostrophe
        ['(', ..] -> KeyPress RoundOpenBracket
        [')', ..] -> KeyPress RoundCloseBracket
        ['*', ..] -> KeyPress Asterisk
        ['+', ..] -> KeyPress PlusSign
        [',', ..] -> KeyPress Comma
        ['-', ..] -> KeyPress Hyphen
        ['.', ..] -> KeyPress FullStop
        ['/', ..] -> KeyPress ForwardSlash
        [':', ..] -> KeyPress Colon
        [';', ..] -> KeyPress SemiColon
        ['<', ..] -> KeyPress LessThanSign
        ['=', ..] -> KeyPress EqualsSign
        ['>', ..] -> KeyPress GreaterThanSign
        ['?', ..] -> KeyPress QuestionMark
        ['@', ..] -> KeyPress AtSign
        ['[', ..] -> KeyPress SquareOpenBracket
        ['\\', ..] -> KeyPress Backslash
        [']', ..] -> KeyPress SquareCloseBracket
        ['^', ..] -> KeyPress Caret
        ['_', ..] -> KeyPress Underscore
        ['`', ..] -> KeyPress GraveAccent
        ['{', ..] -> KeyPress CurlyOpenBrace
        ['|', ..] -> KeyPress VerticalBar
        ['}', ..] -> KeyPress CurlyCloseBrace
        ['~', ..] -> KeyPress Tilde
        ['0', ..] -> KeyPress Number0
        ['1', ..] -> KeyPress Number1
        ['2', ..] -> KeyPress Number2
        ['3', ..] -> KeyPress Number3
        ['4', ..] -> KeyPress Number4
        ['5', ..] -> KeyPress Number5
        ['6', ..] -> KeyPress Number6
        ['7', ..] -> KeyPress Number7
        ['8', ..] -> KeyPress Number8
        ['9', ..] -> KeyPress Number9
        [3, ..] -> CtrlC
        _ -> Unsupported bytes

expect parseRawStdin [27, 91, 65] == KeyPress Up
expect parseRawStdin [27] == KeyPress Escape

inputToStr : Input -> Str
inputToStr = \input ->
    when input is
        KeyPress key -> "Key $(keyToStr key)"
        CtrlC -> "Ctrl-C"
        Unsupported bytes ->
            bytesStr = bytes |> List.map Num.toStr |> Str.joinWith ","
            "Unsupported [$(bytesStr)]"

keyToStr : Key -> Str
keyToStr = \key ->
    when key is
        Up -> "Up"
        Down -> "Down"
        Left -> "Left"
        Right -> "Right"
        Escape -> "Escape"
        Enter -> "Enter"
        Space -> "Space"
        UpperA -> "A"
        LowerA -> "a"
        UpperB -> "B"
        LowerB -> "b"
        UpperC -> "C"
        LowerC -> "c"
        UpperD -> "D"
        LowerD -> "d"
        UpperE -> "E"
        LowerE -> "e"
        UpperF -> "F"
        LowerF -> "f"
        UpperG -> "G"
        LowerG -> "g"
        UpperH -> "H"
        LowerH -> "h"
        UpperI -> "I"
        LowerI -> "i"
        UpperJ -> "J"
        LowerJ -> "j"
        UpperK -> "K"
        LowerK -> "k"
        UpperL -> "L"
        LowerL -> "l"
        UpperM -> "M"
        LowerM -> "m"
        UpperN -> "N"
        LowerN -> "n"
        UpperO -> "O"
        LowerO -> "o"
        UpperP -> "P"
        LowerP -> "p"
        UpperQ -> "Q"
        LowerQ -> "q"
        UpperR -> "R"
        LowerR -> "r"
        UpperS -> "S"
        LowerS -> "s"
        UpperT -> "T"
        LowerT -> "t"
        UpperU -> "U"
        LowerU -> "u"
        UpperV -> "V"
        LowerV -> "v"
        UpperW -> "W"
        LowerW -> "w"
        UpperX -> "X"
        LowerX -> "x"
        UpperY -> "Y"
        LowerY -> "y"
        UpperZ -> "Z"
        LowerZ -> "z"
        ExclamationMark -> "!"
        QuotationMark -> "\""
        NumberSign -> "#"
        DollarSign -> "\$"
        PercentSign -> "%"
        Ampersand -> "&"
        Apostrophe -> "\\"
        RoundOpenBracket -> "("
        RoundCloseBracket -> ")"
        Asterisk -> "*"
        PlusSign -> "+"
        Comma -> ","
        Hyphen -> "-"
        FullStop -> "."
        ForwardSlash -> "/"
        Colon -> ":"
        SemiColon -> ";"
        LessThanSign -> "<"
        EqualsSign -> "="
        GreaterThanSign -> ">"
        QuestionMark -> "?"
        AtSign -> "@"
        SquareOpenBracket -> "["
        Backslash -> "\\"
        SquareCloseBracket -> "]"
        Caret -> "^"
        Underscore -> "_"
        GraveAccent -> "`"
        CurlyOpenBrace -> "{"
        VerticalBar -> "|"
        CurlyCloseBrace -> "}"
        Tilde -> "~"
        Number0 -> "0"
        Number1 -> "1"
        Number2 -> "2"
        Number3 -> "3"
        Number4 -> "4"
        Number5 -> "5"
        Number6 -> "6"
        Number7 -> "7"
        Number8 -> "8"
        Number9 -> "9"

ScreenSize : { width : I32, height : I32 }
Position : { row : I32, col : I32 }
DrawFn : Position, Position -> Result Pixel {}
Pixel : { char : Str, fg : Color, bg : Color, styles : List Style }

parseCursor : List U8 -> Position
parseCursor = \bytes ->
    { val: row, rest: afterFirst } = takeNumber { val: 0, rest: List.dropFirst bytes 2 }
    { val: col } = takeNumber { val: 0, rest: List.dropFirst afterFirst 1 }

    { row, col }

# test "ESC[33;1R"
expect parseCursor [27, 91, 51, 51, 59, 49, 82] == { col: 1, row: 33 }

takeNumber : { val : I32, rest : List U8 } -> { val : I32, rest : List U8 }
takeNumber = \in ->
    when in.rest is
        [a, ..] if a == '0' -> takeNumber { val: in.val * 10 + 0, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '1' -> takeNumber { val: in.val * 10 + 1, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '2' -> takeNumber { val: in.val * 10 + 2, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '3' -> takeNumber { val: in.val * 10 + 3, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '4' -> takeNumber { val: in.val * 10 + 4, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '5' -> takeNumber { val: in.val * 10 + 5, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '6' -> takeNumber { val: in.val * 10 + 6, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '7' -> takeNumber { val: in.val * 10 + 7, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '8' -> takeNumber { val: in.val * 10 + 8, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '9' -> takeNumber { val: in.val * 10 + 9, rest: List.dropFirst in.rest 1 }
        _ -> in

expect takeNumber { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] } == { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }
expect takeNumber { val: 0, rest: [51, 51, 59, 49, 82] } == { val: 33, rest: [59, 49, 82] }
expect takeNumber { val: 0, rest: [49, 82] } == { val: 1, rest: [82] }

updateCursor : { cursor : Position, screen : ScreenSize }a, [Up, Down, Left, Right] -> { cursor : Position, screen : ScreenSize }a
updateCursor = \state, direction ->
    when direction is
        Up ->
            { state &
                cursor: {
                    row: ((state.cursor.row + state.screen.height - 1) % state.screen.height),
                    col: state.cursor.col,
                },
            }

        Down ->
            { state &
                cursor: {
                    row: ((state.cursor.row + 1) % state.screen.height),
                    col: state.cursor.col,
                },
            }

        Left ->
            { state &
                cursor: {
                    row: state.cursor.row,
                    col: ((state.cursor.col + state.screen.width - 1) % state.screen.width),
                },
            }

        Right ->
            { state &
                cursor: {
                    row: state.cursor.row,
                    col: ((state.cursor.col + 1) % state.screen.width),
                },
            }

## Loop through each pixel in screen and build up a single string to write to stdout
drawScreen : { cursor : Position, screen : ScreenSize }*, List DrawFn -> Str
drawScreen = \{ cursor, screen }, drawFns ->
    pixels =
        row <- List.range { start: At 0, end: Before screen.height } |> List.map
        col <- List.range { start: At 0, end: Before screen.width } |> List.map

        List.walkUntil
            drawFns
            { char: " ", fg: Default, bg: Default, styles: [] }
            \defaultPixel, drawFn ->
                when drawFn cursor { row, col } is
                    Ok pixel -> Break pixel
                    Err _ -> Continue defaultPixel

    pixels
    |> joinAllPixels

joinAllPixels : List (List Pixel) -> Str
joinAllPixels = \rows ->

    walkWithIndex = \remaining, idx, state, fn ->
        when remaining is
            [] -> state
            [head, .. as rest] -> walkWithIndex rest (idx + 1) (fn state head idx) fn

    init = {
        char: " ",
        fg: Default,
        bg: Default,
        lines: List.withCapacity (List.len rows),
        styles: [],
    }

    walkWithIndex rows 0 init joinPixelRow
    |> .lines
    |> Str.joinWith ""

joinPixelRow : { char : Str, fg : Color, bg : Color, lines : List Str, styles : List Style }, List Pixel, U64 -> { char : Str, fg : Color, bg : Color, lines : List Str, styles : List Style }
joinPixelRow = \{ char, fg, bg, lines, styles }, pixelRow, row ->

    { rowStrs, prev } =
        List.walk
            pixelRow
            { rowStrs: List.withCapacity (Num.intCast (List.len pixelRow)), prev: { char, fg, bg, styles } }
            joinPixels

    line =
        rowStrs
        |> Str.joinWith "" # Set cursor at the start of line we want to draw
        |> Str.withPrefix (toStr (Control (MoveCursor (To { row: Num.toI32 (row + 1), col: 0 }))))

    { char: " ", fg: prev.fg, bg: prev.bg, lines: List.append lines line, styles: prev.styles }

joinPixels : { rowStrs : List Str, prev : Pixel }, Pixel -> { rowStrs : List Str, prev : Pixel }
joinPixels = \{ rowStrs, prev }, curr ->
    pixelStr =
        # Prepend an ASCII escape ONLY if there is a change between pixels
        curr.char
        |> \str -> if curr.fg != prev.fg then Str.concat (toStr (Control (Style (Foreground curr.fg)))) str else str
        |> \str -> if curr.bg != prev.bg then Str.concat (toStr (Control (Style (Background curr.bg)))) str else str

    { rowStrs: List.append rowStrs pixelStr, prev: curr }

drawBox : { r : I32, c : I32, w : I32, h : I32, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawBox = \{ r, c, w, h, fg ? Default, bg ? Default, char ? "#", styles ? [] } -> \_, { row, col } ->

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

drawVLine : { r : I32, c : I32, len : I32, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawVLine = \{ r, c, len, fg ? Default, bg ? Default, char ? "|", styles ? [] } -> \_, { row, col } ->
        if col == c && (row >= r && row < (r + len)) then
            Ok { char, fg, bg, styles }
        else
            Err {}

drawHLine : { r : I32, c : I32, len : I32, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawHLine = \{ r, c, len, fg ? Default, bg ? Default, char ? "-", styles ? [] } -> \_, { row, col } ->
        if row == r && (col >= c && col < (c + len)) then
            Ok { char, fg, bg, styles }
        else
            Err {}

drawCursor : { fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawCursor = \{ fg ? Default, bg ? Default, char ? " ", styles ? [] } -> \cursor, { row, col } ->
        if (row == cursor.row) && (col == cursor.col) then
            Ok { char, fg, bg, styles }
        else
            Err {}

drawText : Str, { r : I32, c : I32, fg ? Color, bg ? Color, styles ? List Style } -> DrawFn
drawText = \text, { r, c, fg ? Default, bg ? Default, styles ? [] } -> \_, pixel ->
        bytes = Str.toUtf8 text
        len = text |> Str.toUtf8 |> List.len |> Num.toI32
        if pixel.row == r && pixel.col >= c && pixel.col < (c + len) then
            bytes
            |> List.get (Num.intCast (pixel.col - c))
            |> Result.try \b -> Str.fromUtf8 [b]
            |> Result.map \char -> { char, fg, bg, styles }
            |> Result.mapErr \_ -> {}
        else
            Err {}
