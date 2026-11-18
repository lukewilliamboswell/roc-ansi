# Copyright © 2019 Richard Feldman and subsequent Roc authors <roc-lang.org/authors>
# Adapted from roc-lang/unicode 4.3.1; licensed under UPL-1.0.
# SPDX-License-Identifier: UPL-1.0 AND Unicode-3.0
# Source: https://github.com/roc-lang/unicode/tree/4.3.1/package
# Bundle SHA-256: 119846d77be7e87cff22396219a8d060833c4ee2c3b7e54ba94dc2fb7a37d168
# Changes: private module names and compatibility with November 18 Roc.

import UnicodeByteRange
import UnicodeInternalGrapheme

## Extended grapheme cluster boundaries and materializers.
##
## The public contract is range-first and implements the default, un-tailored
## Unicode 17 extended grapheme cluster algorithm.
UnicodeGrapheme :: [].{

	## Incremental segmentation over scalar-aligned `Str` chunks.
	Cursor :: {
		machine : UnicodeInternalGrapheme.Machine,
		byte_offset : U64,
		finished : Bool,
	}.{
		Error : [AlreadyFinished, OffsetOverflow]

		init : {} -> Cursor
		init = |{}| {
			{
				machine: UnicodeInternalGrapheme.init({}),
				byte_offset: 0,
				finished: Bool.False,
			}
		}

		## Consume a chunk and fold each irrevocable cluster range into caller
		## state. A chunk boundary is not treated as end of text.
		push : Cursor, Str, state, (state, UnicodeByteRange -> state) -> Try({ cursor : Cursor, state : state }, Error)
		push = |cursor, chunk, state, emit| {
			if cursor.finished {
				Err(AlreadyFinished)
			} else {
				next_offset = match cursor.byte_offset.plus_try(chunk.count_utf8_bytes()) {
					Err(Overflow) => return Err(OffsetOverflow)
					Ok(offset) => offset
				}
				folded = UnicodeInternalGrapheme.fold_chunk(
					cursor.machine,
					cursor.byte_offset,
					chunk,
					state,
					emit,
				)

				Ok({
					cursor: {
						machine: folded.machine,
						byte_offset: next_offset,
						finished: Bool.False,
					},
					state: folded.state,
				})
			}
		}

		## Mark end of text and emit the final nonempty cluster exactly once.
		finish : Cursor, state, (state, UnicodeByteRange -> state) -> Try({ cursor : Cursor, state : state }, Error)
		finish = |cursor, state, emit| {
			if cursor.finished {
				Err(AlreadyFinished)
			} else {
				final_state = if cursor.machine.started {
					final_range = UnicodeByteRange.from_bounds(
						cursor.machine.cluster_start,
						cursor.byte_offset,
					) ?? ...
					emit(state, final_range)
				} else {
					state
				}

				Ok({
					cursor: {
						machine: cursor.machine,
						byte_offset: cursor.byte_offset,
						finished: Bool.True,
					},
					state: final_state,
				})
			}
		}
	}

	## Visit half-open byte ranges in source order through `Iter`.
	##
	iter_ranges : Str -> Iter(UnicodeByteRange)
	iter_ranges = |source| UnicodeInternalGrapheme.iter_ranges(source)

	## Collect half-open byte ranges in source order.
	ranges : Str -> List(UnicodeByteRange)
	ranges = |source| UnicodeInternalGrapheme.ranges(source)

	## Return seamless slices of the source, retaining its backing storage.
	slices : Str -> List(Str)
	slices = |source| {
		UnicodeInternalGrapheme.ranges(source).map(
			|range| {
				UnicodeByteRange.slice(range, source) ?? ...
			},
		)
	}

	## Split the source into independently materialized cluster strings.
	split : Str -> List(Str)
	split = |source| {
		UnicodeInternalGrapheme.ranges(source).map(
			|range| {
				slice = UnicodeByteRange.slice(range, source) ?? ...
				copied_bytes = slice.to_utf8().map(|byte| byte)
				Str.from_utf8(copied_bytes) ?? ...
			},
		)
	}
}
