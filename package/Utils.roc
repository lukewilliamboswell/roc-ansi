Utils := [].{
	linear_interpolation : (F64, F64), (F64, F64) -> (F64 -> F64)
	linear_interpolation = |a, b|
		|value| {
			t = (value - a.0) / a.1 - a.0
			(b.1 - b.0) * t + b.0
		}

	clamp_u32 : U32, U32, U32 -> U32
	clamp_u32 = |min_value, max_value, value| value.min(max_value).max(min_value)

	manhattan_distance : List(I64), List(I64) -> I64
	manhattan_distance = |point1, point2| {
		List.map2(point1, point2, |a, b| (a - b).abs())
			.fold(0, |acc, value| acc + value)
	}
}

expect Utils.manhattan_distance([1, 2, 3], [4, 6, 8]) == 12
