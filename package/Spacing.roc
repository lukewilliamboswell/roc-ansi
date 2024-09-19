module [xw, yw]

# Horizontal whitespace
xw = " "
# Vertical whitespace
yw = "\n"

Spacing : [
    Padding (Options, U64),
    # Margin Options,
    # Border Border
]

Options : [Top, Right, Bottom, Left]
# Border : [Width Options, Color Options, Style Options]

internal : Spacing -> (Str -> Str)
internal = \spacing ->
    \str ->
        when spacing is
            Padding (opts, val) ->
                when opts is
                    Top -> Str.repeat yw val |> Str.concat str
                    Right -> str |> Str.concat (Str.repeat xw val)
                    Bottom -> str |> Str.concat (Str.repeat yw val)
                    Left -> Str.repeat xw val |> Str.concat str

expect (internal (Padding (Top, 3))) "Hello" == "\n\n\nHello"
expect (internal (Padding (Right, 2))) "Hello" == "Hello  "
expect (internal (Padding (Bottom, 3))) "Hello" == "Hello\n\n\n"
expect (internal (Padding (Left, 2))) "Hello" == "  Hello"

# Vertical align (top, middle, bottom, sep)
# Horizontal align (left, center, right, sep)
