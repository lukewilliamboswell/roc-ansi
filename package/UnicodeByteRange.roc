# Copyright © 2019 Richard Feldman and subsequent Roc authors <roc-lang.org/authors>
# Adapted from roc-lang/unicode 4.3.1; licensed under UPL-1.0.
# SPDX-License-Identifier: UPL-1.0 AND Unicode-3.0
# Source: https://github.com/roc-lang/unicode/tree/4.3.1/package
# Bundle SHA-256: 119846d77be7e87cff22396219a8d060833c4ee2c3b7e54ba94dc2fb7a37d168
# Changes: private module names and compatibility with November 18 Roc.

## A half-open range of UTF-8 bytes in an original text source.
UnicodeByteRange :: { start : U64, end : U64 }.{
	BoundsError : [EndBeforeStart]
	SliceError : [NotScalarBoundary, OutOfBounds]

	## Construct `[start, end)`. Empty ranges are valid.
	from_bounds : U64, U64 -> Try(UnicodeByteRange, BoundsError)
	from_bounds = |first, last| {
		if first <= last {
			Ok({ start: first, end: last })
		} else {
			Err(EndBeforeStart)
		}
	}

	start : UnicodeByteRange -> U64
	start = |range| range.start

	end : UnicodeByteRange -> U64
	end = |range| range.end

	len : UnicodeByteRange -> U64
	len = |range| range.end - range.start

	is_empty : UnicodeByteRange -> Bool
	is_empty = |range| range.start == range.end

	is_eq : UnicodeByteRange, UnicodeByteRange -> Bool
	is_eq = |left, right| {
		left.start == right.start and left.end == right.end
	}

	## Select this range as a seamless slice of `source`.
	##
	## The returned string retains the source backing allocation and does not
	## copy the selected bytes.
	slice : UnicodeByteRange, Str -> Try(Str, SliceError)
	slice = |range, source| {
		source_len = source.count_utf8_bytes()

		if range.end > source_len {
			Err(OutOfBounds)
		} else {
			match source.drop_first_bytes(range.start) {
				Err(_) => Err(NotScalarBoundary)
				Ok(after_start) => {
					match after_start.drop_last_bytes(source_len - range.end) {
						Err(_) => Err(NotScalarBoundary)
						Ok(selected) => Ok(selected)
					}
				}
			}
		}
	}
}
