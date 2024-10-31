module [
    linearInterpolation,
    manhattanDistance,
    clamp,
    mean,
    median,
    variance,
    standardDeviation,
]

linearInterpolation = \a, b -> \value ->
        t = value |> Num.sub a.0 |> Num.div a.1 |> Num.sub a.0
        b.1 |> Num.sub b.0 |> Num.mul t |> Num.add b.0

clamp = \a, b -> \value ->
        value |> Num.min b |> Num.max a

manhattanDistance = \point1, point2 ->
    List.map2 point1 point2 Num.sub
    |> List.map Num.abs
    |> List.walk 0 Num.add

expect manhattanDistance [1, 2, 3] [4, 6, 8] == 12

mean : List (Frac a) -> Frac a
mean = \xs -> xs |> List.walk 0 Num.add |> Num.div (List.len xs |> Num.toFrac)

expect
    actual = mean [6, 7]
    expected = 6.5
    Num.isApproxEq actual expected { atol: 0 }

variance : List (Frac a) -> Frac a
variance = \xs ->
    squaredDiffs = List.map xs (\x -> x |> Num.sub (mean xs) |> Num.pow 2)
    mean squaredDiffs

standardDeviation : List (Frac a) -> Frac a
standardDeviation = \xs ->
    variance xs |> Num.pow 0.5 # Num.sqrt not working

testData1 = [10, 12, 23, 23, 16, 23, 21, 16]

expect mean testData1 == 18
expect variance testData1 == 24
expect Num.isApproxEq (standardDeviation testData1) 4.8989794855664 { atol: 0 }

testData2 = [9, 11, 8, 63, 5, 13, 10]

expect mean testData2 == 17
expect variance testData2 == 358
expect standardDeviation testData2 |> Num.isApproxEq 18.920887928425 { atol: 0 }

median : List (Frac a) -> [Err [Empty, OutOfBounds], Ok (Frac a)]
median = \xs ->
    if List.isEmpty xs then
        Err Empty
    else
        sorted = List.sortAsc xs
        len = List.len sorted
        indices = (
            if len % 2 == 1 then
                # Odd number of elements, take the middle one
                [(len - 1) // 2]
            else
                # Even number of elements, take the average of the two middle ones
                [len // 2 - 1, len // 2]
        )
        middle = indices |> List.mapTry (\a -> sorted |> List.get a)
        when middle is
            Ok a -> Ok (List.walk a 0 Num.add)
            Err e -> Err e

expect median testData2 == Ok 10
