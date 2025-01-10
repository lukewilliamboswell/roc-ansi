module [Control, to_code]

import Style exposing [Style]

## [Control](https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences) (commonly known as Control Sequence Introducer or CSI)
## represents the control sequences for terminal commands.
## The provided commands are common and well-supported, though not exhaustive.
Control : [
    Screen [Size],
    Cursor
        [
            Position [Get, Save, Restore],
            Display [On, Off],
            ## Move relatively by a specified number of rows up or down, or columns left or right.
            Rel [Up, Down, Left, Right] U16,
            ## Move relatively by a specified number of rows next or previous (and to the first column of the corresponding row).
            Row [Next, Prev] U16,
            ## Move absolutely to the specified row and column.
            Abs { row : U16, col : U16 },
            ## Move absolutely to the specified column in the current row.
            Col U16,
        ],
    Erase
        [
            Display [ToEnd, ToStart, All],
            Line [ToEnd, ToStart, All],
        ],
    Scroll [Up, Down] U16,
    Style Style,
]

to_code : Control -> Str
to_code = \a ->
    when a is
        Screen(b) ->
            when b is
                Size -> "18t"

        Cursor(b) ->
            when b is
                Position(state) ->
                    when state is
                        Get -> "6n"
                        Save -> "s"
                        Restore -> "u"

                Display(state) ->
                    "?25"
                    |> Str.concat(
                        when state is
                            On -> "l"
                            Off -> "h",
                    )

                Rel(direction, number) ->
                    Num.to_str(number)
                    |> Str.concat(
                        when direction is
                            Up -> "A"
                            Down -> "B"
                            Right -> "C"
                            Left -> "D",
                    )

                Row(direction, number) ->
                    Num.to_str(number)
                    |> Str.concat(
                        when direction is
                            Next -> "E"
                            Prev -> "F",
                    )

                Abs({ row, col }) -> [row, col] |> List.map(Num.to_str) |> Str.join_with(";") |> Str.concat("H")
                Col(col) -> col |> Num.to_str |> Str.concat("G")

        Erase(b) ->
            when b is
                Display(d) ->
                    (
                        when d is
                            ToEnd -> 0
                            ToStart -> 1
                            All -> 2
                        # ClearScreen -> 3
                    )
                    |> Num.to_str
                    |> Str.concat("J")

                Line(l) ->
                    (
                        when l is
                            ToEnd -> 0
                            ToStart -> 1
                            All -> 2
                    )
                    |> Num.to_str
                    |> Str.concat("K")

        Scroll(direction, lines) ->
            Num.to_str(lines)
            |> Str.concat(
                when direction is
                    Up -> "S"
                    Down -> "T",
            )

        Style(style) -> style |> Style.to_code |> List.map(Num.to_str) |> Str.join_with(";") |> Str.concat("m")
