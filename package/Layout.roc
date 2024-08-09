module [drawGrid]

import Utils
import Spacing

BorderFill a : { start : a, base : a, end : a, sep : a }
BorderSection a : { top : a, middle : a, data : a, bottom : a }

squaredBorder : BorderSection (BorderFill Str)
squaredBorder = {
    top: { base: "─", sep: "┬", start: "┌", end: "┐" },
    middle: { base: "─", sep: "┼", start: "├", end: "┤" },
    data: { base: " ", sep: "│", start: "│", end: "│" },
    bottom: { base: "─", sep: "┴", start: "└", end: "┘" },
}

roundedBorder : BorderSection (BorderFill Str)
roundedBorder = {
    top: { base: "─", sep: "┬", start: "╭", end: "╮" },
    middle: { base: "─", sep: "┼", start: "├", end: "┤" },
    data: { base: " ", sep: "│", start: "│", end: "│" },
    bottom: { base: "─", sep: "┴", start: "╰", end: "╯" },
}

prettyBorder : BorderSection (BorderFill Str)
prettyBorder = {
    top: { base: "─", sep: "─", start: "╭", end: "╮" },
    middle: { base: "─", sep: " ", start: "│", end: "│" },
    data: { base: " ", sep: " ", start: "│", end: "│" },
    bottom: { base: "─", sep: "─", start: "╰", end: "╯" },
}

# Option value : Result value [None]
# noBorder : BorderFill (Option Str)
# noBorder = { base: Err None, sep: Err None, start: Err None, end: Err None }

# Display strategies

testData = ["ProductID", "ProductName", "Category", "Price", "StockQuantity", "SupplierID", "101", "Laptop", "Electronics", "1200", "50", "2001", "102", "Smartphone", "Electronics", "800", "150", "2002", "103", "Office Chair", "Furniture", "150", "300", "2003", "104", "Coffee Maker", "Appliances", "100", "200", "2004", "105", "Desk Lamp", "Lighting", "50", "500", "2005", "106", "Microwave", "Appliances", "150", "250", "2004"]

dataToRows = \data, (rows, cols) ->
    List.range { start: At 0, end: Before rows }
    |> List.mapTry \rowIndex ->
        List.range { start: At 0, end: Before cols }
        |> List.mapTry \colIndex ->
            List.get data (rowIndex * cols + colIndex)

expect
    actual = dataToRows testData (7, 6) |> Result.withDefault []
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
dataToColumns = \data, (rows, cols) ->
    List.range { start: At 0, end: Before cols }
    |> List.mapTry \colIndex ->
        List.range { start: At 0, end: Before rows }
        |> List.mapTry \rowIndex ->
            List.get data (rowIndex * cols + colIndex)

expect
    actual = dataToColumns testData (7, 6) |> Result.withDefault []
    expected = [
        ["ProductID", "101", "102", "103", "104", "105", "106"],
        ["ProductName", "Laptop", "Smartphone", "Office Chair", "Coffee Maker", "Desk Lamp", "Microwave"],
        ["Category", "Electronics", "Electronics", "Furniture", "Appliances", "Lighting", "Appliances"],
        ["Price", "1200", "800", "150", "100", "50", "150"],
        ["StockQuantity", "50", "150", "300", "200", "500", "250"],
        ["SupplierID", "2001", "2002", "2003", "2004", "2005", "2004"],
    ]
    expected == actual

testRows = dataToRows testData (7, 6) |> Result.withDefault []
testHeader = testRows |> List.get 0 |> Result.withDefault []

## Truncates or pads a string to fit a specified size.
## It only works for left-to-right writing.
## It only truncates for single line words (horizontal size only). TODO: Add multiline support (breakdown words, add hyphen)?
## It only pads to the right. TODO: Add word alignment support?
truncOrPad = \truncChar, padChar ->
    \str, size ->
        if size == 0 then
            ""
        else
            data = Str.toUtf8 str
            len = List.len data
            if len > size then
                ## The string is larger the specified size, truncate it and append the truncation character.
                truncated = data |> List.takeFirst (size - 1) |> Str.fromUtf8 |> Result.withDefault ""
                truncated |> Str.concat truncChar
            else if len < size then
                ## The string is shorter than the specified size, pad it with the padding character.
                rightPad = size - len
                str |> Str.concat (Str.repeat padChar rightPad)
            else
                ## If the string is exactly the specified size, return it as is.
                str

drawRow : List Str, List U64, BorderFill Str -> Str
drawRow = \data, sizes, border ->
    (
        when data is
            [] -> List.map sizes \_ -> ""
            d -> d
    )
    |> List.map2 sizes (truncOrPad "…" border.base)
    |> List.intersperse (border.sep)
    |> List.prepend (border.start)
    |> List.append (border.end)
    |> Str.joinWith ""

expect drawRow testHeader [0, 1, 2, 3, 4] squaredBorder.data == "││…│C…│Pr…│Sto…│"
expect drawRow testHeader [5, 6, 7, 8, 9, 10, 11] squaredBorder.data == "│Prod…│Produ…│Catego…│Price   │StockQua…│SupplierID│"

expect drawRow [] [0] squaredBorder.top == "┌┐"
expect drawRow [] [1] squaredBorder.top == "┌─┐"
expect drawRow [] [0, 1, 2, 3] squaredBorder.top == "┌┬─┬──┬───┐"
expect drawRow [] [0, 1, 2, 3] squaredBorder.middle == "├┼─┼──┼───┤"
expect drawRow [] [0, 1, 2, 3] squaredBorder.data == "││ │  │   │"
expect drawRow [] [0, 1, 2, 3] squaredBorder.bottom == "└┴─┴──┴───┘"
expect drawRow [] [1, 0] roundedBorder.top == "╭─┬╮"
expect drawRow [] [1, 0] roundedBorder.middle == "├─┼┤"
expect drawRow [] [1, 0] roundedBorder.data == "│ ││"
expect drawRow [] [1, 0] roundedBorder.bottom == "╰─┴╯"

testColumns = dataToColumns testData (7, 6) |> Result.withDefault []
testColumn = testColumns |> List.get 0 |> Result.withDefault []

getDataLength = \a -> a |> Str.toUtf8 |> List.len |> Num.toFrac

expect testColumn |> List.map getDataLength == [9, 3, 3, 3, 3, 3, 3]

# NOTE: This is an ARBITRARY function
# When a value in the list is outside the standard deviation
# it replaces it with another value (in this case I chose the mean as the replacer)
fixAnomalies = \xs, k ->
    mean = Utils.mean xs
    stdDev = Utils.standardDeviation xs
    t = Num.mul stdDev k
    replaceFn = \threshold, average, replacer -> \elem ->
            if Num.absDiff elem average > threshold then
                replacer
            else
                elem
    xs |> List.map (replaceFn t mean mean) |> List.map Num.floor

# Estimate the sizes when the user doesn't provide them
estimateSize = \xs -> fixAnomalies xs 2 |> List.walk 0 Num.max

testSizes = testColumns |> List.map (\x -> x |> List.map getDataLength |> estimateSize)

expect
    actual = testSizes
    expected = [3, 12, 11, 5, 4, 4]
    actual == expected

# TODO: Make middle border optional
drawGrid : List (List Str), List U64, BorderSection (BorderFill Str) -> Str
drawGrid = \grid, sizes, border ->
    List.map grid (\row -> (row, border.data))
    |> List.intersperse ([], border.middle)
    |> List.prepend ([], border.top)
    |> List.append ([], border.bottom)
    |> List.map (\(d, b) -> drawRow d sizes b)
    |> Str.joinWith Spacing.yw

expect
    actual = drawGrid [["Apple", "Banana", "Cat"], ["Dog", "Elephant", "Fish"]] [2, 2, 2] squaredBorder
    expected =
        """
        ┌──┬──┬──┐
        │A…│B…│C…│
        ├──┼──┼──┤
        │D…│E…│F…│
        └──┴──┴──┘
        """
    actual == expected

# TODO:
# Maybe sizes should be a struct that has { width: U16, height: U16, flex ? U16 } instead of a single list of U16
# Maybe headers should be data
# It should derive from the drawGrid function!
drawTable = \rows, sizes, border ->
    when rows is
        [] -> ""
        [head, .. as tail] ->
            t = drawRow [] sizes border.top
            h = drawRow head sizes border.data
            m = drawRow [] sizes border.middle
            d = tail |> List.map (\a -> drawRow a sizes border.data) |> Str.joinWith Spacing.yw
            b = drawRow [] sizes border.bottom
            [t, h, m, d, b] |> Str.joinWith Spacing.yw

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
