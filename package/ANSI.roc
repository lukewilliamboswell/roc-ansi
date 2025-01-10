module [
    # ANSI
    Escape,
    Color,
    to_str,
    style,
    color,

    # TUI
    DrawFn,
    Pixel,
    ScreenSize,
    CursorPosition,
    Input,
    parse_cursor,
    update_cursor,
    input_to_str,
    parse_raw_stdin,
    draw_screen,
    draw_text,
    draw_v_line,
    draw_h_line,
    draw_box,
    draw_cursor,
    symbol_to_str,
    lower_to_str,
    upper_to_str,
]

import Color
import Style exposing [Style]
import Control exposing [Control]

Color : Color.Color

## [Ansi Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
Escape : [
    Reset,
    Control Control,
]

to_str : Escape -> Str
to_str = \escape ->
    "\u(001b)"
    |> Str.concat(
        when escape is
            Reset -> "c"
            Control(control) -> "[" |> Str.concat(Control.to_code(control)),
    )

## Add styles to a string
style : Str, List Style -> Str
style = \str, styles ->
    styles
    |> List.map(Style)
    |> List.map(Control)
    |> List.map(to_str)
    |> List.append(str)
    |> Str.join_with("")

reset_style = "" |> style([Default])

## Add color styles to a string and then resets to default
color : Str, { fg ?? Color, bg ?? Color } -> Str
color = \str, { fg ?? Default, bg ?? Default } -> str |> style([Foreground(fg), Background(bg)]) |> Str.concat(reset_style)

Symbol : [
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
]

Ctrl : [Space, A, B, C, D, E, F, G, H, I, J, K, L, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, BackSlash, SquareCloseBracket, Caret, Underscore]
Action : [Escape, Enter, Space, Delete]
Arrow : [Up, Down, Left, Right]
Number : [N0, N1, N2, N3, N4, N5, N6, N7, N8, N9]
Letter : [A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z]

Input : [
    Ctrl Ctrl,
    Action Action,
    Arrow Arrow,
    Symbol Symbol,
    Number Number,
    Upper Letter,
    Lower Letter,
    Unsupported (List U8),
]

parse_raw_stdin : List U8 -> Input
parse_raw_stdin = \bytes ->
    when bytes is
        [0, ..] -> Ctrl(Space)
        [1, ..] -> Ctrl(A)
        [2, ..] -> Ctrl(B)
        [3, ..] -> Ctrl(C)
        [4, ..] -> Ctrl(D)
        [5, ..] -> Ctrl(E)
        [6, ..] -> Ctrl(F)
        [7, ..] -> Ctrl(G)
        [8, ..] -> Ctrl(H)
        [9, ..] -> Ctrl(I)
        [10, ..] -> Ctrl(J)
        [11, ..] -> Ctrl(K)
        [12, ..] -> Ctrl(L)
        [13, ..] -> Action(Enter)
        # [13, ..] -> Ctrl M # Same as Action Enter
        [14, ..] -> Ctrl(N)
        [15, ..] -> Ctrl(O)
        [16, ..] -> Ctrl(P)
        [17, ..] -> Ctrl(Q)
        [18, ..] -> Ctrl(R)
        [19, ..] -> Ctrl(S)
        [20, ..] -> Ctrl(T)
        [21, ..] -> Ctrl(U)
        [22, ..] -> Ctrl(V)
        [23, ..] -> Ctrl(W)
        [24, ..] -> Ctrl(X)
        [25, ..] -> Ctrl(Y)
        [26, ..] -> Ctrl(Z)
        [27, 91, 'A', ..] -> Arrow(Up)
        [27, 91, 'B', ..] -> Arrow(Down)
        [27, 91, 'C', ..] -> Arrow(Right)
        [27, 91, 'D', ..] -> Arrow(Left)
        [27, ..] -> Action(Escape)
        # [27, ..] -> Ctrl SquareOpenBracket # Same as Action Escape
        [28, ..] -> Ctrl(BackSlash)
        [29, ..] -> Ctrl(SquareCloseBracket)
        [30, ..] -> Ctrl(Caret)
        [31, ..] -> Ctrl(Underscore)
        [32, ..] -> Action(Space)
        ['!', ..] -> Symbol(ExclamationMark)
        ['"', ..] -> Symbol(QuotationMark)
        ['#', ..] -> Symbol(NumberSign)
        ['$', ..] -> Symbol(DollarSign)
        ['%', ..] -> Symbol(PercentSign)
        ['&', ..] -> Symbol(Ampersand)
        ['\'', ..] -> Symbol(Apostrophe)
        ['(', ..] -> Symbol(RoundOpenBracket)
        [')', ..] -> Symbol(RoundCloseBracket)
        ['*', ..] -> Symbol(Asterisk)
        ['+', ..] -> Symbol(PlusSign)
        [',', ..] -> Symbol(Comma)
        ['-', ..] -> Symbol(Hyphen)
        ['.', ..] -> Symbol(FullStop)
        ['/', ..] -> Symbol(ForwardSlash)
        ['0', ..] -> Number(N0)
        ['1', ..] -> Number(N1)
        ['2', ..] -> Number(N2)
        ['3', ..] -> Number(N3)
        ['4', ..] -> Number(N4)
        ['5', ..] -> Number(N5)
        ['6', ..] -> Number(N6)
        ['7', ..] -> Number(N7)
        ['8', ..] -> Number(N8)
        ['9', ..] -> Number(N9)
        [':', ..] -> Symbol(Colon)
        [';', ..] -> Symbol(SemiColon)
        ['<', ..] -> Symbol(LessThanSign)
        ['=', ..] -> Symbol(EqualsSign)
        ['>', ..] -> Symbol(GreaterThanSign)
        ['?', ..] -> Symbol(QuestionMark)
        ['@', ..] -> Symbol(AtSign)
        ['A', ..] -> Upper(A)
        ['B', ..] -> Upper(B)
        ['C', ..] -> Upper(C)
        ['D', ..] -> Upper(D)
        ['E', ..] -> Upper(E)
        ['F', ..] -> Upper(F)
        ['G', ..] -> Upper(G)
        ['H', ..] -> Upper(H)
        ['I', ..] -> Upper(I)
        ['J', ..] -> Upper(J)
        ['K', ..] -> Upper(K)
        ['L', ..] -> Upper(L)
        ['M', ..] -> Upper(M)
        ['N', ..] -> Upper(N)
        ['O', ..] -> Upper(O)
        ['P', ..] -> Upper(P)
        ['Q', ..] -> Upper(Q)
        ['R', ..] -> Upper(R)
        ['S', ..] -> Upper(S)
        ['T', ..] -> Upper(T)
        ['U', ..] -> Upper(U)
        ['V', ..] -> Upper(V)
        ['W', ..] -> Upper(W)
        ['X', ..] -> Upper(X)
        ['Y', ..] -> Upper(Y)
        ['Z', ..] -> Upper(Z)
        ['[', ..] -> Symbol(SquareOpenBracket)
        ['\\', ..] -> Symbol(Backslash)
        [']', ..] -> Symbol(SquareCloseBracket)
        ['^', ..] -> Symbol(Caret)
        ['_', ..] -> Symbol(Underscore)
        ['`', ..] -> Symbol(GraveAccent)
        ['a', ..] -> Lower(A)
        ['b', ..] -> Lower(B)
        ['c', ..] -> Lower(C)
        ['d', ..] -> Lower(D)
        ['e', ..] -> Lower(E)
        ['f', ..] -> Lower(F)
        ['g', ..] -> Lower(G)
        ['h', ..] -> Lower(H)
        ['i', ..] -> Lower(I)
        ['j', ..] -> Lower(J)
        ['k', ..] -> Lower(K)
        ['l', ..] -> Lower(L)
        ['m', ..] -> Lower(M)
        ['n', ..] -> Lower(N)
        ['o', ..] -> Lower(O)
        ['p', ..] -> Lower(P)
        ['q', ..] -> Lower(Q)
        ['r', ..] -> Lower(R)
        ['s', ..] -> Lower(S)
        ['t', ..] -> Lower(T)
        ['u', ..] -> Lower(U)
        ['v', ..] -> Lower(V)
        ['w', ..] -> Lower(W)
        ['x', ..] -> Lower(X)
        ['y', ..] -> Lower(Y)
        ['z', ..] -> Lower(Z)
        ['{', ..] -> Symbol(CurlyOpenBrace)
        ['|', ..] -> Symbol(VerticalBar)
        ['}', ..] -> Symbol(CurlyCloseBrace)
        ['~', ..] -> Symbol(Tilde)
        [127, ..] -> Action(Delete)
        _ -> Unsupported(bytes)

expect parse_raw_stdin([27, 91, 65]) == Arrow(Up)
expect parse_raw_stdin([27]) == Action(Escape)

input_to_str : Input -> Str
input_to_str = \input ->
    when input is
        Ctrl(key) -> "Ctrl - " |> Str.concat(ctrl_to_str(key))
        Action(key) -> "Action " |> Str.concat(action_to_str(key))
        Arrow(key) -> "Arrow " |> Str.concat(arrow_to_str(key))
        Symbol(key) -> "Symbol " |> Str.concat(symbol_to_str(key))
        Number(key) -> "Number " |> Str.concat(number_to_str(key))
        Upper(key) -> "Letter " |> Str.concat(upper_to_str(key))
        Lower(key) -> "Letter " |> Str.concat(lower_to_str(key))
        Unsupported(bytes) ->
            bytes_str = bytes |> List.map(Num.to_str) |> Str.join_with(",")
            "Unsupported [$(bytes_str)]"

ctrl_to_str : Ctrl -> Str
ctrl_to_str = \ctrl ->
    when ctrl is
        A -> "A"
        B -> "B"
        C -> "C"
        D -> "D"
        E -> "E"
        F -> "F"
        G -> "G"
        H -> "H"
        I -> "I"
        J -> "J"
        K -> "K"
        L -> "L"
        # M -> "M"
        N -> "N"
        O -> "O"
        P -> "P"
        Q -> "Q"
        R -> "R"
        S -> "S"
        T -> "T"
        U -> "U"
        V -> "V"
        W -> "W"
        X -> "X"
        Y -> "Y"
        Z -> "Z"
        Space -> "[Space]"
        # OpenSquareBracket -> "["
        BackSlash -> "\\"
        SquareCloseBracket -> "]"
        Caret -> "^"
        Underscore -> "_"

action_to_str : Action -> Str
action_to_str = \action ->
    when action is
        Escape -> "Escape"
        Enter -> "Enter"
        Space -> "Space"
        Delete -> "Delete"

arrow_to_str : Arrow -> Str
arrow_to_str = \arrow ->
    when arrow is
        Up -> "Up"
        Down -> "Down"
        Left -> "Left"
        Right -> "Right"

symbol_to_str : Symbol -> Str
symbol_to_str = \symbol ->
    when symbol is
        ExclamationMark -> "!"
        QuotationMark -> "\""
        NumberSign -> "#"
        DollarSign -> "\$"
        PercentSign -> "%"
        Ampersand -> "&"
        Apostrophe -> "'"
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

number_to_str : Number -> Str
number_to_str = \number ->
    when number is
        N0 -> "0"
        N1 -> "1"
        N2 -> "2"
        N3 -> "3"
        N4 -> "4"
        N5 -> "5"
        N6 -> "6"
        N7 -> "7"
        N8 -> "8"
        N9 -> "9"

upper_to_str : Letter -> Str
upper_to_str = \letter ->
    when letter is
        A -> "A"
        B -> "B"
        C -> "C"
        D -> "D"
        E -> "E"
        F -> "F"
        G -> "G"
        H -> "H"
        I -> "I"
        J -> "J"
        K -> "K"
        L -> "L"
        M -> "M"
        N -> "N"
        O -> "O"
        P -> "P"
        Q -> "Q"
        R -> "R"
        S -> "S"
        T -> "T"
        U -> "U"
        V -> "V"
        W -> "W"
        X -> "X"
        Y -> "Y"
        Z -> "Z"

lower_to_str : Letter -> Str
lower_to_str = \letter ->
    when letter is
        A -> "a"
        B -> "b"
        C -> "c"
        D -> "d"
        E -> "e"
        F -> "f"
        G -> "g"
        H -> "h"
        I -> "i"
        J -> "j"
        K -> "k"
        L -> "l"
        M -> "m"
        N -> "n"
        O -> "o"
        P -> "p"
        Q -> "q"
        R -> "r"
        S -> "s"
        T -> "t"
        U -> "u"
        V -> "v"
        W -> "w"
        X -> "x"
        Y -> "y"
        Z -> "z"

ScreenSize : { width : U16, height : U16 }
CursorPosition : { row : U16, col : U16 }
DrawFn : CursorPosition, CursorPosition -> Result Pixel {}
Pixel : { char : Str, fg : Color, bg : Color, styles : List Style }

parse_cursor : List U8 -> CursorPosition
parse_cursor = \bytes ->
    { val: row, rest: after_first } = take_number({ val: 0, rest: List.drop_first(bytes, 2) })
    { val: col } = take_number({ val: 0, rest: List.drop_first(after_first, 1) })

    { row, col }

# test "ESC[33;1R"
expect parse_cursor([27, 91, 51, 51, 59, 49, 82]) == { row: 33, col: 1 }

take_number : { val : U16, rest : List U8 } -> { val : U16, rest : List U8 }
take_number = \in ->
    when in.rest is
        [a, ..] if a == '0' -> take_number({ val: in.val * 10 + 0, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '1' -> take_number({ val: in.val * 10 + 1, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '2' -> take_number({ val: in.val * 10 + 2, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '3' -> take_number({ val: in.val * 10 + 3, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '4' -> take_number({ val: in.val * 10 + 4, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '5' -> take_number({ val: in.val * 10 + 5, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '6' -> take_number({ val: in.val * 10 + 6, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '7' -> take_number({ val: in.val * 10 + 7, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '8' -> take_number({ val: in.val * 10 + 8, rest: List.drop_first(in.rest, 1) })
        [a, ..] if a == '9' -> take_number({ val: in.val * 10 + 9, rest: List.drop_first(in.rest, 1) })
        _ -> in

expect take_number({ val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }) == { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }
expect take_number({ val: 0, rest: [51, 51, 59, 49, 82] }) == { val: 33, rest: [59, 49, 82] }
expect take_number({ val: 0, rest: [49, 82] }) == { val: 1, rest: [82] }

update_cursor : { cursor : CursorPosition, screen : ScreenSize }a, [Up, Down, Left, Right] -> { cursor : CursorPosition, screen : ScreenSize }a
update_cursor = \state, direction ->
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
draw_screen : { cursor : CursorPosition, screen : ScreenSize }*, List DrawFn -> Str
draw_screen = \{ cursor, screen }, draw_fns ->
    pixels =
        List.map(
            List.range({ start: At(0), end: Before(screen.height) }),
            \row ->
                List.map(
                    List.range({ start: At(0), end: Before(screen.width) }),
                    \col ->
                        List.walk_until(
                            draw_fns,
                            { char: " ", fg: Default, bg: Default, styles: [] },
                            \default_pixel, draw_fn ->
                                when draw_fn(cursor, { row, col }) is
                                    Ok(pixel) -> Break(pixel)
                                    Err(_) -> Continue(default_pixel),
                        ),
                ),
        )

    pixels
    |> join_all_pixels

join_all_pixels : List (List Pixel) -> Str
join_all_pixels = \rows ->

    walk_with_index = \remaining, idx, state, fn ->
        when remaining is
            [] -> state
            [head, .. as rest] -> walk_with_index(rest, (idx + 1), fn(state, head, idx), fn)

    init = {
        char: " ",
        fg: Default,
        bg: Default,
        lines: List.with_capacity(List.len(rows)),
        styles: [],
    }

    walk_with_index(rows, 0, init, join_pixel_row)
    |> .lines
    |> Str.join_with("")

join_pixel_row : { char : Str, fg : Color, bg : Color, lines : List Str, styles : List Style }, List Pixel, U64 -> { char : Str, fg : Color, bg : Color, lines : List Str, styles : List Style }
join_pixel_row = \{ char, fg, bg, lines, styles }, pixel_row, row ->

    { row_strs, prev } =
        List.walk(
            pixel_row,
            { row_strs: List.with_capacity(Num.int_cast(List.len(pixel_row))), prev: { char, fg, bg, styles } },
            join_pixels,
        )

    line =
        row_strs
        |> Str.join_with("") # Set cursor at the start of line we want to draw
        |> Str.with_prefix(to_str(Control(Cursor(Abs({ row: Num.to_u16((row + 1)), col: 0 })))))

    { char: " ", fg: prev.fg, bg: prev.bg, lines: List.append(lines, line), styles: prev.styles }

join_pixels : { row_strs : List Str, prev : Pixel }, Pixel -> { row_strs : List Str, prev : Pixel }
join_pixels = \{ row_strs, prev }, curr ->
    pixel_str =
        # Prepend an ASCII escape ONLY if there is a change between pixels
        curr.char
        |> \str -> if curr.fg != prev.fg then Str.concat(to_str(Control(Style(Foreground(curr.fg)))), str) else str
        |> \str -> if curr.bg != prev.bg then Str.concat(to_str(Control(Style(Background(curr.bg)))), str) else str

    { row_strs: List.append(row_strs, pixel_str), prev: curr }

draw_box : { r : U16, c : U16, w : U16, h : U16, fg ?? Color, bg ?? Color, char ?? Str, styles ?? List Style } -> DrawFn
draw_box = \{ r, c, w, h, fg ?? Default, bg ?? Default, char ?? "#", styles ?? [] } ->
    \_, { row, col } ->

        start_row = r
        end_row = (r + h)
        start_col = c
        end_col = (c + w)

        if row == r && (col >= start_col && col < end_col) then
            Ok({ char, fg, bg, styles }) # TOP BORDER
        else if row == (r + h - 1) && (col >= start_col && col < end_col) then
            Ok({ char, fg, bg, styles }) # BOTTOM BORDER
        else if col == c && (row >= start_row && row < end_row) then
            Ok({ char, fg, bg, styles }) # LEFT BORDER
        else if col == (c + w - 1) && (row >= start_row && row < end_row) then
            Ok({ char, fg, bg, styles }) # RIGHT BORDER
        else
            Err({})

draw_v_line : { r : U16, c : U16, len : U16, fg ?? Color, bg ?? Color, char ?? Str, styles ?? List Style } -> DrawFn
draw_v_line = \{ r, c, len, fg ?? Default, bg ?? Default, char ?? "|", styles ?? [] } ->
    \_, { row, col } ->
        if col == c && (row >= r && row < (r + len)) then
            Ok({ char, fg, bg, styles })
        else
            Err({})

draw_h_line : { r : U16, c : U16, len : U16, fg ?? Color, bg ?? Color, char ?? Str, styles ?? List Style } -> DrawFn
draw_h_line = \{ r, c, len, fg ?? Default, bg ?? Default, char ?? "-", styles ?? [] } ->
    \_, { row, col } ->
        if row == r && (col >= c && col < (c + len)) then
            Ok({ char, fg, bg, styles })
        else
            Err({})

draw_cursor : { fg ?? Color, bg ?? Color, char ?? Str, styles ?? List Style } -> DrawFn
draw_cursor = \{ fg ?? Default, bg ?? Default, char ?? " ", styles ?? [] } ->
    \cursor, { row, col } ->
        if (row == cursor.row) && (col == cursor.col) then
            Ok({ char, fg, bg, styles })
        else
            Err({})

draw_text : Str, { r : U16, c : U16, fg ?? Color, bg ?? Color, styles ?? List Style } -> DrawFn
draw_text = \text, { r, c, fg ?? Default, bg ?? Default, styles ?? [] } ->
    \_, pixel ->
        bytes = Str.to_utf8(text)
        len = text |> Str.to_utf8 |> List.len |> Num.to_u16
        if pixel.row == r && pixel.col >= c && pixel.col < (c + len) then
            bytes
            |> List.get(Num.int_cast((pixel.col - c)))
            |> Result.try(\b -> Str.from_utf8([b]))
            |> Result.map(\char -> { char, fg, bg, styles })
            |> Result.map_err(\_ -> {})
        else
            Err({})
