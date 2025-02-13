module [drawGrid]

import Utils
import Spacing

# Taken from MDN
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

squaredBorder : LineFill (LineFill Str)
squaredBorder = {
    start: { start: "┌", base: "─", sep: "┬", end: "┐" },
    base: { start: "│", base: " ", sep: "│", end: "│" },
    sep: { start: "├", base: "─", sep: "┼", end: "┤" },
    end: { start: "└", base: "─", sep: "┴", end: "┘" },
}

roundedBorder : LineFill (LineFill Str)
roundedBorder = {
    start: { start: "╭", base: "─", sep: "┬", end: "╮" },
    base: { start: "│", base: " ", sep: "│", end: "│" },
    sep: { start: "├", base: "─", sep: "┼", end: "┤" },
    end: { start: "╰", base: "─", sep: "┴", end: "╯" },
}

prettyBorder : LineFill (LineFill Str)
prettyBorder = {
    start: { start: "╭", base: "─", sep: "─", end: "╮" },
    base: { start: "│", base: " ", sep: " ", end: "│" },
    sep: { start: "│", base: "─", sep: " ", end: "│" },
    end: { start: "╰", base: "─", sep: "─", end: "╯" },
}

# Display strategies

testData = ["ProductID", "ProductName", "Category", "Price", "StockQuantity", "SupplierID", "101", "Laptop", "Electronics", "1200", "50", "2001", "102", "Smartphone", "Electronics", "800", "150", "2002", "103", "Office Chair", "Furniture", "150", "300", "2003", "104", "Coffee Maker", "Appliances", "100", "200", "2004", "105", "Desk Lamp", "Lighting", "50", "500", "2005", "106", "Microwave", "Appliances", "150", "250", "2004"]

dataToRows = |data, (rows, cols)|
    List.range { start: At 0, end: Before rows }
    |> List.map_try |rowIndex|
        List.range { start: At 0, end: Before cols }
        |> List.map_try |colIndex|
            List.get data (rowIndex * cols + colIndex)

expect
    actual = dataToRows testData (7, 6) |> Result.with_default []
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

dataToColumns : List a, (U64, U64) -> Result (List (List a)) [OutOfBounds]
dataToColumns = |data, (rows, cols)|
    List.range { start: At 0, end: Before cols }
    |> List.map_try |colIndex|
        List.range { start: At 0, end: Before rows }
        |> List.map_try |rowIndex|
            List.get data (rowIndex * cols + colIndex)

expect
    actual = dataToColumns testData (7, 6) |> Result.with_default []
    expected = [
        ["ProductID", "101", "102", "103", "104", "105", "106"],
        ["ProductName", "Laptop", "Smartphone", "Office Chair", "Coffee Maker", "Desk Lamp", "Microwave"],
        ["Category", "Electronics", "Electronics", "Furniture", "Appliances", "Lighting", "Appliances"],
        ["Price", "1200", "800", "150", "100", "50", "150"],
        ["StockQuantity", "50", "150", "300", "200", "500", "250"],
        ["SupplierID", "2001", "2002", "2003", "2004", "2005", "2004"],
    ]
    expected == actual

testRows = dataToRows testData (7, 6) |> Result.with_default []
testHeader = testRows |> List.get 0 |> Result.with_default []

## Truncates or pads a string to fit a specified size.
## It only works for left-to-right writing.
## It only truncates for single line words (horizontal size only). TODO: Add multiline support (breakdown words, add hyphen)?
## It only pads to the right. TODO: Add word alignment support?
truncOrPad : Str, Str -> (Str, U64 -> Str)
truncOrPad = |truncChar, fillChar|
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
drawRow : List Str, List U64, LineFill Str, { mx ?? (Num *, Num *)a, px ?? (Num *, Num *)a }* -> Str
drawRow = |data, sizes, border, { px ?? (0, 0), mx ?? (0, 0) }|
    fill = |elem, size| List.range { start: At 0, end: Before size } |> List.map (|_| elem)
    block =
        (
            when data is
                [] -> List.map sizes |_| ""
                d -> d
        )
        |> List.map2 sizes (truncOrPad "…" border.base)

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

expect drawRow testHeader [0, 1, 2, 3, 4] squaredBorder.base {} == "││…│C…│Pr…│Sto…│"
expect drawRow testHeader [5, 6, 7, 8, 9, 10, 11] squaredBorder.base {} == "│Prod…│Produ…│Catego…│Price   │StockQua…│SupplierID│"

expect drawRow [] [1, 0] squaredBorder.start {} == "┌─┬┐"
expect drawRow [] [1, 0] squaredBorder.sep {} == "├─┼┤"
expect drawRow [] [1, 0] squaredBorder.base {} == "│ ││"
expect drawRow [] [1, 0] squaredBorder.end {} == "└─┴┘"
expect drawRow [] [1, 0] roundedBorder.start {} == "╭─┬╮"
expect drawRow [] [1, 0] roundedBorder.sep {} == "├─┼┤"
expect drawRow [] [1, 0] roundedBorder.base {} == "│ ││"
expect drawRow [] [1, 0] roundedBorder.end {} == "╰─┴╯"

testColumns = dataToColumns testData (7, 6) |> Result.with_default []
testColumn = testColumns |> List.get 0 |> Result.with_default []

getDataLength = |a| a |> Str.to_utf8 |> List.len |> Num.to_frac

expect testColumn |> List.map getDataLength == [9, 3, 3, 3, 3, 3, 3]

# NOTE: This is an ARBITRARY function
# When a value in the list is outside the standard deviation
# it replaces it with another value (in this case I chose the mean as the replacer)
fixAnomalies = |xs, k|
    mean = Utils.mean xs
    stdDev = Utils.standard_deviation xs
    t = Num.mul stdDev k
    replaceFn = |threshold, average, replacer|
        |elem|
            if Num.abs_diff elem average > threshold then
                replacer
            else
                elem
    xs |> List.map (replaceFn t mean mean) |> List.map Num.floor

# Estimate the sizes when the user doesn't provide them
autoSize = |xs| fixAnomalies xs 2 |> List.walk 0 Num.max

testSizes = testColumns |> List.map (|x| x |> List.map getDataLength |> autoSize)

expect
    actual = testSizes
    expected = [3, 12, 11, 5, 4, 4]
    actual == expected

# TODO: How to make borders optional?
drawGrid :
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
drawGrid = |grid, sizes, border, { mx ?? (0, 0), my ?? (0, 0), px ?? (0, 0), py ?? (0, 0) }|
    paddingFill = ([], { base: "░", sep: border.base.sep, start: border.base.start, end: border.base.end }) # This should only be blank space, Spacing.xw?
    marginFill = ([], { base: "░", sep: "░", start: "░", end: "░" }) # This should only be blank space, Spacing.xw?
    fill = |elem, size| List.range { start: At 0, end: Before size } |> List.map (|_| elem)
    x = List.map
        grid
        (|row|
            [
                fill paddingFill py.0, # Padding top
                [(row, border.base)], # Content
                fill paddingFill py.1, # Padding bottom
            ]
            |> List.join)
    x
    |> List.intersperse (fill ([], border.sep) 1) # Border between
    |> List.prepend (fill ([], border.start) 1) # Border top
    |> List.prepend (fill marginFill my.0) # Margin top
    |> List.append (fill ([], border.end) 1) # Border bottom
    |> List.append (fill marginFill my.1) # Margin bottom
    |> List.join
    |> List.map (|(d, b)| drawRow d sizes b { px, mx })
    |> Str.join_with Spacing.yw

expect
    actual = drawGrid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squaredBorder {}
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
    actual = drawGrid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squaredBorder { mx: (1, 2), my: (1, 2) }
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
    actual = drawGrid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squaredBorder { px: (1, 2), py: (1, 2) }
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
# It should derive from the drawGrid function!
drawTable : List (List Str), List U64, LineFill (LineFill Str) -> Str
drawTable = |rows, sizes, border|
    when rows is
        [] -> ""
        [head, .. as tail] ->
            t = drawRow [] sizes border.start {}
            h = drawRow head sizes border.base {}
            m = drawRow [] sizes border.sep {}
            d = tail |> List.map (|a| drawRow a sizes border.base {}) |> Str.join_with Spacing.yw
            b = drawRow [] sizes border.end {}
            [t, h, m, d, b] |> Str.join_with Spacing.yw

expect
    actual = drawTable testRows testSizes prettyBorder
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
