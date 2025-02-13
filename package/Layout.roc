module [draw_grid]

import Utils
import Spacing

# [Dir](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/dir)
# [Direction](https://developer.mozilla.org/en-US/docs/Web/CSS/direction)
# dir An enumerated attribute indicating the directionality of the element's text. It can have the following values:
# ltr, which means left to right and is to be used for languages that are written from the left to the right (like English);
# rtl, which means right to left and is to be used for languages that are written from the right to the left (like Arabic);
# Dir : [Ltr, Rtl]

# toStr : Dir -> Str
# toStr = \dir ->
#    when dir is
#        Ltr -> "ltr"
#        Rtl -> "rtl"

LineFill a : { start : a, base : a, end : a, sep : a }

squared_border : LineFill (LineFill Str)
squared_border = {
    start: { start: "┌", base: "─", sep: "┬", end: "┐" },
    base: { start: "│", base: " ", sep: "│", end: "│" },
    sep: { start: "├", base: "─", sep: "┼", end: "┤" },
    end: { start: "└", base: "─", sep: "┴", end: "┘" },
}

rounded_border : LineFill (LineFill Str)
rounded_border = {
    start: { start: "╭", base: "─", sep: "┬", end: "╮" },
    base: { start: "│", base: " ", sep: "│", end: "│" },
    sep: { start: "├", base: "─", sep: "┼", end: "┤" },
    end: { start: "╰", base: "─", sep: "┴", end: "╯" },
}

pretty_border : LineFill (LineFill Str)
pretty_border = {
    start: { start: "╭", base: "─", sep: "─", end: "╮" },
    base: { start: "│", base: " ", sep: " ", end: "│" },
    sep: { start: "│", base: "─", sep: " ", end: "│" },
    end: { start: "╰", base: "─", sep: "─", end: "╯" },
}

# Display strategies

test_data = ["ProductID", "ProductName", "Category", "Price", "StockQuantity", "SupplierID", "101", "Laptop", "Electronics", "1200", "50", "2001", "102", "Smartphone", "Electronics", "800", "150", "2002", "103", "Office Chair", "Furniture", "150", "300", "2003", "104", "Coffee Maker", "Appliances", "100", "200", "2004", "105", "Desk Lamp", "Lighting", "50", "500", "2005", "106", "Microwave", "Appliances", "150", "250", "2004"]

data_to_rows = |data, (rows, cols)|
    List.range { start: At 0, end: Before rows }
    |> List.map_try |rowIndex|
        List.range { start: At 0, end: Before cols }
        |> List.map_try |colIndex|
            List.get data (rowIndex * cols + colIndex)

expect
    actual = data_to_rows test_data (7, 6) |> Result.with_default []
    expected = [
        ["ProductID", "ProductName", "Category", "Price", "StockQuantity", "SupplierID"],
        ["101", "Laptop", "Electronics", "1200", "50", "2001"],
        ["102", "Smartphone", "Electronics", "800", "150", "2002"],
        ["103", "Office Chair", "Furniture", "150", "300", "2003"],
        ["104", "Coffee Maker", "Appliances", "100", "200", "2004"],
        ["105", "Desk Lamp", "Lighting", "50", "500", "2005"],
        ["106", "Microwave", "Appliances", "150", "250", "2004"],
    ]
    actual == expected

data_to_columns : List a, (U64, U64) -> Result (List (List a)) [OutOfBounds]
data_to_columns = |data, (rows, cols)|
    List.range { start: At 0, end: Before cols }
    |> List.map_try |colIndex|
        List.range { start: At 0, end: Before rows }
        |> List.map_try |rowIndex|
            List.get data (rowIndex * cols + colIndex)

expect
    actual = data_to_columns test_data (7, 6) |> Result.with_default []
    expected = [
        ["ProductID", "101", "102", "103", "104", "105", "106"],
        ["ProductName", "Laptop", "Smartphone", "Office Chair", "Coffee Maker", "Desk Lamp", "Microwave"],
        ["Category", "Electronics", "Electronics", "Furniture", "Appliances", "Lighting", "Appliances"],
        ["Price", "1200", "800", "150", "100", "50", "150"],
        ["StockQuantity", "50", "150", "300", "200", "500", "250"],
        ["SupplierID", "2001", "2002", "2003", "2004", "2005", "2004"],
    ]
    expected == actual

test_rows = data_to_rows test_data (7, 6) |> Result.with_default []
test_header = test_rows |> List.get 0 |> Result.with_default []

## Truncates or pads a string to fit a specified size.
## It only works for left-to-right writing.
## It only truncates for single line words (horizontal size only). TODO: Add multiline support (breakdown words, add hyphen)?
## It only pads to the right. TODO: Add word alignment support?
trunc_or_pad : Str, Str -> (Str, U64 -> Str)
trunc_or_pad = |truncChar, fillChar|
    |str, size|
        if size == 0 then
            ""
        else
            data = Str.to_utf8 str
            len = List.len data
            if len > size then
                ## The string is larger the specified size, truncate it and append the truncation character.
                truncated = data |> List.take_first (size - 1) |> Str.from_utf8 |> Result.with_default ""
                truncated |> Str.concat truncChar
            else if len < size then
                ## The string is shorter than the specified size, pad it with the padding character.
                rightPad = size - len
                str |> Str.concat (Str.repeat fillChar rightPad)
            else
                ## If the string is exactly the specified size, return it as is.
                str

# This should draw a list of Nodes, not a list of Str?
draw_row : List Str, List U64, LineFill Str, { mx ?? (Num *, Num *)a, px ?? (Num *, Num *)a }* -> Str
draw_row = |data, sizes, border, { px ?? (0, 0), mx ?? (0, 0) }|
    fill = |elem, size| List.range { start: At 0, end: Before size } |> List.map (|_| elem)
    block =
        (
            when data is
                [] -> List.map sizes |_| ""
                d -> d
        )
        |> List.map2 sizes (trunc_or_pad "…" border.base)

    blocks =
        List.map
            block
            (
                |cell|
                    [
                        fill "░" px.0, # Padding left (maybe use border.base?)
                        [cell], # Content
                        fill "░" px.1, # Padding right (maybe use border.base?)
                    ]
                    |> List.map (|x| Str.join_with x "")
                    |> Str.join_with ""
            )

    [
        blocks
        |> List.intersperse border.sep,
    ]
    |> List.prepend (fill border.start 1) # Border left
    |> List.prepend (fill "░" mx.0) # Margin left
    |> List.append (fill border.end 1) # Border right
    |> List.append (fill "░" mx.1) # Margin right
    |> List.join
    |> Str.join_with ""

expect draw_row test_header [0, 1, 2, 3, 4] squared_border.base {} == "││…│C…│Pr…│Sto…│"
expect draw_row test_header [5, 6, 7, 8, 9, 10, 11] squared_border.base {} == "│Prod…│Produ…│Catego…│Price   │StockQua…│SupplierID│"

expect draw_row [] [1, 0] squared_border.start {} == "┌─┬┐"
expect draw_row [] [1, 0] squared_border.sep {} == "├─┼┤"
expect draw_row [] [1, 0] squared_border.base {} == "│ ││"
expect draw_row [] [1, 0] squared_border.end {} == "└─┴┘"
expect draw_row [] [1, 0] rounded_border.start {} == "╭─┬╮"
expect draw_row [] [1, 0] rounded_border.sep {} == "├─┼┤"
expect draw_row [] [1, 0] rounded_border.base {} == "│ ││"
expect draw_row [] [1, 0] rounded_border.end {} == "╰─┴╯"

test_columns = data_to_columns test_data (7, 6) |> Result.with_default []
test_column = test_columns |> List.get 0 |> Result.with_default []

get_data_length = |a| a |> Str.to_utf8 |> List.len |> Num.to_frac

expect test_column |> List.map get_data_length == [9, 3, 3, 3, 3, 3, 3]

# NOTE: This is an ARBITRARY function
# When a value in the list is outside the standard deviation
# it replaces it with another value (in this case I chose the mean as the replacer)
fix_anomalies = |xs, k|
    mean = Utils.mean xs
    std_dev = Utils.standard_deviation xs
    t = Num.mul std_dev k
    replace_fn = |threshold, average, replacer|
        |elem|
            if Num.abs_diff elem average > threshold then
                replacer
            else
                elem
    xs |> List.map (replace_fn t mean mean) |> List.map Num.floor

# Estimate the sizes when the user doesn't provide them
auto_size = |xs| fix_anomalies xs 2 |> List.walk 0 Num.max

test_sizes = test_columns |> List.map (|x| x |> List.map get_data_length |> auto_size)

expect
    actual = test_sizes
    expected = [3, 12, 11, 5, 4, 4]
    actual == expected

# TODO: How to make borders optional?
draw_grid :
    List (List Str),
    List U64,
    LineFill (LineFill Str),
    {
        mx ?? (Int *, Int *),
        my ?? (Int *, Int *),
        px ?? (Int *, Int *),
        py ?? (Int *, Int *),
    }
    -> Str
draw_grid = |grid, sizes, border, { mx ?? (0, 0), my ?? (0, 0), px ?? (0, 0), py ?? (0, 0) }|
    padding_fill = ([], { base: "░", sep: border.base.sep, start: border.base.start, end: border.base.end }) # This should only be blank space, Spacing.xw?
    margin_fill = ([], { base: "░", sep: "░", start: "░", end: "░" }) # This should only be blank space, Spacing.xw?
    fill = |elem, size| List.range { start: At 0, end: Before size } |> List.map (|_| elem)
    List.map
        grid
        (|row|
            [
                fill padding_fill py.0, # Padding top
                [(row, border.base)], # Content
                fill padding_fill py.1, # Padding bottom
            ]
            |> List.join)
    |> List.intersperse (fill ([], border.sep) 1) # Border between
    |> List.prepend (fill ([], border.start) 1) # Border top
    |> List.prepend (fill margin_fill my.0) # Margin top
    |> List.append (fill ([], border.end) 1) # Border bottom
    |> List.append (fill margin_fill my.1) # Margin bottom
    |> List.join
    |> List.map (|(d, b)| draw_row d sizes b { px, mx })
    |> Str.join_with Spacing.yw

expect
    actual = draw_grid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squared_border {}
    expected =
        """
        ┌──┬──┬──┐
        │A…│B…│C…│
        ├──┼──┼──┤
        │D…│E…│F…│
        └──┴──┴──┘
        """
    actual == expected

expect
    actual = draw_grid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squared_border { mx: (1, 2), my: (1, 2) }
    expected =
        """
        ░░░░░░░░░░░░░
        ░┌──┬──┬──┐░░
        ░│A…│B…│C…│░░
        ░├──┼──┼──┤░░
        ░│D…│E…│F…│░░
        ░└──┴──┴──┘░░
        ░░░░░░░░░░░░░
        ░░░░░░░░░░░░░
        """
    actual == expected

expect
    actual = draw_grid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squared_border { px: (1, 2), py: (1, 2) }
    expected =
        """
        ┌░──░░┬░──░░┬░──░░┐
        │░░░░░│░░░░░│░░░░░│
        │░A…░░│░B…░░│░C…░░│
        │░░░░░│░░░░░│░░░░░│
        │░░░░░│░░░░░│░░░░░│
        ├░──░░┼░──░░┼░──░░┤
        │░░░░░│░░░░░│░░░░░│
        │░D…░░│░E…░░│░F…░░│
        │░░░░░│░░░░░│░░░░░│
        │░░░░░│░░░░░│░░░░░│
        └░──░░┴░──░░┴░──░░┘
        """
    actual == expected

# TODO:
# Maybe sizes should be a struct that has { width: U16, height: U16, flex ? U16 } instead of a single list of U16
# Maybe headers should be data
# It should derive from the draw_grid function!
draw_table : List (List Str), List U64, LineFill (LineFill Str) -> Str
draw_table = |rows, sizes, border|
    when rows is
        [] -> ""
        [head, .. as tail] ->
            t = draw_row [] sizes border.start {}
            h = draw_row head sizes border.base {}
            m = draw_row [] sizes border.sep {}
            d = tail |> List.map (|a| draw_row a sizes border.base {}) |> Str.join_with Spacing.yw
            b = draw_row [] sizes border.end {}
            [t, h, m, d, b] |> Str.join_with Spacing.yw

expect
    actual = draw_table test_rows test_sizes pretty_border
    expected =
        """
        ╭────────────────────────────────────────────╮
        │Pr… ProductName  Category    Price Sto… Sup…│
        │─── ──────────── ─────────── ───── ──── ────│
        │101 Laptop       Electronics 1200  50   2001│
        │102 Smartphone   Electronics 800   150  2002│
        │103 Office Chair Furniture   150   300  2003│
        │104 Coffee Maker Appliances  100   200  2004│
        │105 Desk Lamp    Lighting    50    500  2005│
        │106 Microwave    Appliances  150   250  2004│
        ╰────────────────────────────────────────────╯
        """
    actual == expected

# TODO: How to shrink or grow the columns to the size of the container
# This should be applied after estimating the sizes (if the user didn't provide them)
# The user should be able to add a width but also
# if the size shouldnt change (flex = 0)
# or if the size should change (flex != 0)
