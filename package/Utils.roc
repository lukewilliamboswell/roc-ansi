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
		point1.map2(point2, |a, b| (a - b).abs())
			.fold(0, |acc, value| acc + value)
	}

	mean : List(F64) -> F64
	mean = |values| {
		if values.is_empty() {
			0
		} else {
			values.fold(0, |acc, value| acc + value) / U64.to_f64(values.len())
		}
	}

	variance : List(F64) -> F64
	variance = |values| {
		average = Utils.mean(values)
		squared_diffs = values.map(
			|value| {
				diff = value - average
				diff * diff
			},
		)

		Utils.mean(squared_diffs)
	}

	standard_deviation : List(F64) -> F64
	standard_deviation = |values| sqrt(Utils.variance(values))

	median : List(F64) -> Try(F64, [Empty])
	median = |values| {
		if values.is_empty() {
			Err(Empty)
		} else {
			sorted = sort_f64(values)
			len = sorted.len()

			if len % 2 == 1 {
				middle = (len - 1) // 2

				match sorted.get(middle) {
					Ok(value) => Ok(value)
					Err(_) => Err(Empty)
				}
			} else {
				right = len // 2
				left = right - 1

				match (sorted.get(left), sorted.get(right)) {
					(Ok(left_value), Ok(right_value)) => Ok((left_value + right_value) / 2)
					_ => Err(Empty)
				}
			}
		}
	}
}

## Manhattan distance sums absolute coordinate differences.
expect Utils.manhattan_distance([1, 2, 3], [4, 6, 8]) == 12

## Mean averages non-empty lists.
expect Utils.mean([6, 7]) == 6.5

## Mean returns zero at the empty-list boundary.
expect Utils.mean([]) == 0

## Variance averages squared differences from the mean.
expect Utils.variance([10, 12, 23, 23, 16, 23, 21, 16]) == 24

## Standard deviation is the square root of variance.
expect (Utils.standard_deviation([10, 12, 23, 23, 16, 23, 21, 16]) - 4.8989794855664).abs() < 0.000001

## Median returns the middle value for odd-length lists.
expect {
	actual = Utils.median([9, 11, 8, 63, 5, 13, 10])?
	actual == 10
}

## Median averages the two middle values for even-length lists.
expect {
	actual = Utils.median([6, 7])?
	actual == 6.5
}

## Median reports empty input explicitly.
expect Utils.median([]) == Err(Empty)

sqrt : F64 -> F64
sqrt = |value| {
	if value <= 0 {
		0
	} else {
		initial_guess = if value < 1 {
			1
		} else {
			value / 2
		}
		sqrt_step(value, initial_guess, 16)
	}
}

sqrt_step : F64, F64, U8 -> F64
sqrt_step = |value, guess, remaining| {
	if remaining == 0 {
		guess
	} else {
		sqrt_step(value, (guess + value / guess) / 2, remaining - 1)
	}
}

sort_f64 : List(F64) -> List(F64)
sort_f64 = |values| values.fold([], insert_sorted_f64)

insert_sorted_f64 : List(F64), F64 -> List(F64)
insert_sorted_f64 = |sorted, value| {
	match sorted {
		[] => [value]
		[first, ..] if value <= first => [value].concat(sorted)
		[first, .. as rest] => [first].concat(insert_sorted_f64(rest, value))
	}
}
