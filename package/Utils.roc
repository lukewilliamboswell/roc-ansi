module [
    linear_interpolation,
    manhattan_distance,
    clamp,
    mean,
    median,
    variance,
    standard_deviation,
]

linear_interpolation = |a, b|
    |value|
        t = value |> Num.sub(a.0) |> Num.div(a.1) |> Num.sub(a.0)
        b.1 |> Num.sub(b.0) |> Num.mul(t) |> Num.add(b.0)

clamp = |a, b|
    |value|
        value |> Num.min(b) |> Num.max(a)

manhattan_distance = |point1, point2|
    List.map2(point1, point2, Num.sub)
    |> List.map(Num.abs)
    |> List.walk(0, Num.add)

expect manhattan_distance [1, 2, 3] [4, 6, 8] == 12

mean : List (Frac a) -> Frac a
mean = |xs| xs |> List.walk 0 Num.add |> Num.div (List.len xs |> Num.to_frac)

expect
    actual = mean [6, 7]
    expected = 6.5
    Num.is_approx_eq actual expected { atol: 0 }

variance : List (Frac a) -> Frac a
variance = |xs|
    squared_diffs = List.map xs (|x| x |> Num.sub (mean xs) |> Num.pow 2)
    mean squared_diffs

standard_deviation : List (Frac a) -> Frac a
standard_deviation = |xs|
    variance xs |> Num.pow 0.5 # Num.sqrt not working

test_data_1 = [10, 12, 23, 23, 16, 23, 21, 16]

expect mean test_data_1 == 18
expect variance test_data_1 == 24
expect Num.is_approx_eq (standard_deviation test_data_1) 4.8989794855664 { atol: 0 }

test_data_2 = [9, 11, 8, 63, 5, 13, 10]

expect mean test_data_2 == 17
expect variance test_data_2 == 358
expect standard_deviation test_data_2 |> Num.is_approx_eq 18.920887928425 { atol: 0 }

median : List (Frac a) -> [Err [Empty, OutOfBounds], Ok (Frac a)]
median = |xs|
    if List.is_empty xs then
        Err Empty
    else
        sorted = List.sort_asc xs
        len = List.len sorted
        indices = (
            if len % 2 == 1 then
                # Odd number of elements, take the middle one
                [(len - 1) // 2]
            else
                # Even number of elements, take the average of the two middle ones
                [len // 2 - 1, len // 2]
        )
        middle = indices |> List.map_try (|a| sorted |> List.get a)
        when middle is
            Ok a -> Ok (List.walk a 0 Num.add)
            Err e -> Err e

expect median test_data_2 == Ok 10
