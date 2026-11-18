# Copyright © 2019 Richard Feldman and subsequent Roc authors <roc-lang.org/authors>
# Adapted from roc-lang/unicode 4.3.1; licensed under UPL-1.0.
# SPDX-License-Identifier: UPL-1.0 AND Unicode-3.0
# Source: https://github.com/roc-lang/unicode/tree/4.3.1/package
# Bundle SHA-256: 119846d77be7e87cff22396219a8d060833c4ee2c3b7e54ba94dc2fb7a37d168
# Changes: private module names and compatibility with November 18 Roc.

import UnicodeByteRange
import UnicodeInternalGraphemeData
import UnicodeInternalUtf8

EmojiContext : [NoEmojiContext, AfterExtendedPictographic, AfterExtendedPictographicZwj]

IndicContext : [NoIndicContext, AfterConsonant, AfterLinker]

MachineState : {
	started : Bool,
	cluster_start : U64,
	previous : UnicodeInternalGraphemeData.GCB,
	ri_odd : Bool,
	emoji_context : EmojiContext,
	indic_context : IndicContext,
}

Boundary : [NoBoundary, Boundary({ start : U64, end : U64 })]

RangeIterState : {
	cursor : UnicodeInternalUtf8.Cursor,
	machine : MachineState,
	finished : Bool,
}

## Unicode 17 extended grapheme cluster transition core.
UnicodeInternalGrapheme :: [].{
	Machine : MachineState

	init : {} -> Machine
	init = |{}| {
		{
			started: Bool.False,
			cluster_start: 0,
			previous: Other,
			ri_odd: Bool.False,
			emoji_context: NoEmojiContext,
			indic_context: NoIndicContext,
		}
	}

	push : Machine, U32, U64 -> { machine : Machine, boundary : Boundary }
	push = |machine, scalar, byte_start| {
		props = UnicodeInternalGraphemeData.lookup(scalar)
		push_with_props(machine, props, byte_start)
	}

	fold_chunk : Machine, U64, Str, state, (state, UnicodeByteRange -> state) -> { machine : Machine, state : state }
	fold_chunk = |machine, absolute_start, chunk, initial, emit| {
		UnicodeInternalUtf8.fold_with_ascii_blocks(
			chunk,
			{ machine, state: initial },
			|fold_state, scalar, local_start, _local_end, _scalar_index| {
				transition = UnicodeInternalGrapheme.push(
					fold_state.machine,
					scalar,
					absolute_start + local_start,
				)
				emitted = match transition.boundary {
					NoBoundary => fold_state.state
					Boundary({ start, end }) => {
						range = UnicodeByteRange.from_bounds(start, end) ?? ...
						emit(fold_state.state, range)
					}
				}
				{ machine: transition.machine, state: emitted }
			},
			|fold_state, vector, local_start, _scalar_index| {
				fold_ascii_block(
					fold_state,
					vector,
					absolute_start + local_start,
					emit,
				)
			},
		)
	}

	iter_ranges : Str -> Iter(UnicodeByteRange)
	iter_ranges = |source| {
		Iter.custom(
			{
				cursor: UnicodeInternalUtf8.init(source),
				machine: UnicodeInternalGrapheme.init({}),
				finished: Bool.False,
			},
			Err(Unknown),
			next_range,
		)
	}

	ranges : Str -> List(UnicodeByteRange)
	ranges = |source| {
		folded = UnicodeInternalGrapheme.fold_chunk(
			UnicodeInternalGrapheme.init({}),
			0,
			source,
			[],
			|collected, range| collected.append(range),
		)

		if folded.machine.started {
			final_range = UnicodeByteRange.from_bounds(
				folded.machine.cluster_start,
				source.count_utf8_bytes(),
			) ?? ...
			folded.state.append(final_range)
		} else {
			folded.state
		}
	}
}

fold_ascii_block = |fold_state, vector, absolute_start, emit| {
	if is_printable_ascii_block(vector) {
		first = push_with_props(
			fold_state.machine,
			ascii_props(0x20),
			absolute_start,
		)
		var $state = match first.boundary {
			NoBoundary => fold_state.state
			Boundary({ start, end }) => {
				range = UnicodeByteRange.from_bounds(start, end) ?? ...
				emit(fold_state.state, range)
			}
		}

		var $lane = 1.U64
		var $range_start = first.machine.cluster_start
		while $lane < 16 {
			range_end = absolute_start + $lane
			range = UnicodeByteRange.from_bounds($range_start, range_end) ?? ...
			$state = emit($state, range)
			$range_start = range_end
			$lane = $lane + 1
		}

		{
			machine: {
				started: Bool.True,
				cluster_start: absolute_start + 15,
				previous: Other,
				ri_odd: Bool.False,
				emoji_context: NoEmojiContext,
				indic_context: NoIndicContext,
			},
			state: $state,
		}
	} else {
		var $machine = fold_state.machine
		var $state = fold_state.state
		var $lane = 0.U64

		while $lane < 16 {
			byte = vector.get_lane($lane)
			byte_start = absolute_start + $lane
			transition = push_with_props($machine, ascii_props(byte), byte_start)
			$machine = transition.machine
			match transition.boundary {
				NoBoundary => {}
				Boundary({ start, end }) => {
					range = UnicodeByteRange.from_bounds(start, end) ?? ...
					$state = emit($state, range)
				}
			}
			$lane = $lane + 1
		}

		{ machine: $machine, state: $state }
	}
}

is_printable_ascii_block : U8x16 -> Bool
is_printable_ascii_block = |vector| {
	at_least_space = vector.gte_lanes(U8x16.splat(0x20))
	at_most_tilde = vector.lte_lanes(U8x16.splat(0x7E))
	at_least_space.bitwise_and(at_most_tilde).all_lanes_set()
}

ascii_props : U8 -> UnicodeInternalGraphemeData.Props
ascii_props = |byte| {
	gcb = if byte == 0x0D {
		CR
	} else if byte == 0x0A {
		LF
	} else if byte < 0x20 or byte == 0x7F {
		Control
	} else {
		Other
	}

	{ gcb, incb: None, extended_pictographic: Bool.False }
}

next_range : RangeIterState -> Try((UnicodeByteRange, RangeIterState), [NoMore])
next_range = |state| {
	if state.finished {
		return Err(NoMore)
	}

	var $cursor = state.cursor
	var $machine = state.machine

	while Bool.True {
		match UnicodeInternalUtf8.next($cursor) {
			Done => {
				if $machine.started {
					range = UnicodeByteRange.from_bounds($machine.cluster_start, $cursor.byte_offset) ?? ...
					return Ok((
						range,
						{
							cursor: $cursor,
							machine: $machine,
							finished: Bool.True,
						},
					))
				} else {
					return Err(NoMore)
				}
			}
			One({ item, rest }) => {
				transition = UnicodeInternalGrapheme.push($machine, item.scalar, item.byte_start)
				$cursor = rest
				$machine = transition.machine

				match transition.boundary {
					NoBoundary => {}
					Boundary({ start, end }) => {
						range = UnicodeByteRange.from_bounds(start, end) ?? ...
						return Ok((
							range,
							{
								cursor: $cursor,
								machine: $machine,
								finished: Bool.False,
							},
						))
					}
				}
			}
		}
	}
}

should_break : MachineState, UnicodeInternalGraphemeData.Props -> Bool
should_break = |machine, current| {
	previous = machine.previous

	if previous == CR and current.gcb == LF {
		Bool.False
	} else if is_control(previous) {
		Bool.True
	} else if is_control(current.gcb) {
		Bool.True
	} else if previous == L and (current.gcb == L or current.gcb == V or current.gcb == LV or current.gcb == LVT) {
		Bool.False
	} else if (previous == LV or previous == V) and (current.gcb == V or current.gcb == T) {
		Bool.False
	} else if (previous == LVT or previous == T) and current.gcb == T {
		Bool.False
	} else if current.gcb == Extend or current.gcb == ZWJ {
		Bool.False
	} else if current.gcb == SpacingMark {
		Bool.False
	} else if previous == Prepend {
		Bool.False
	} else if current.incb == Consonant and machine.indic_context == AfterLinker {
		Bool.False
	} else if current.extended_pictographic and machine.emoji_context == AfterExtendedPictographicZwj {
		Bool.False
	} else if previous == RI and current.gcb == RI and machine.ri_odd {
		Bool.False
	} else {
		Bool.True
	}
}

push_with_props : MachineState, UnicodeInternalGraphemeData.Props, U64 -> { machine : MachineState, boundary : Boundary }
push_with_props = |machine, props, byte_start| {
	if !machine.started {
		{
			machine: advance_context(machine, props, byte_start, Bool.True),
			boundary: NoBoundary,
		}
	} else {
		breaks = should_break(machine, props)
		boundary = if breaks {
			Boundary({ start: machine.cluster_start, end: byte_start })
		} else {
			NoBoundary
		}

		{
			machine: advance_context(machine, props, byte_start, breaks),
			boundary,
		}
	}
}

is_control : UnicodeInternalGraphemeData.GCB -> Bool
is_control = |gcb| gcb == Control or gcb == CR or gcb == LF

advance_context : MachineState, UnicodeInternalGraphemeData.Props, U64, Bool -> MachineState
advance_context = |machine, current, byte_start, broke_before| {
	prior_emoji = if (broke_before) NoEmojiContext else machine.emoji_context
	prior_indic = if (broke_before) NoIndicContext else machine.indic_context

	next_ri_odd = if current.gcb == RI {
		if !broke_before and machine.previous == RI {
			!machine.ri_odd
		} else {
			Bool.True
		}
	} else {
		Bool.False
	}

	next_emoji = if current.extended_pictographic {
		AfterExtendedPictographic
	} else {
		match (prior_emoji, current.gcb) {
			(AfterExtendedPictographic, Extend) => AfterExtendedPictographic
			(AfterExtendedPictographic, ZWJ) => AfterExtendedPictographicZwj
			_ => NoEmojiContext
		}
	}

	next_indic = match current.incb {
		Consonant => AfterConsonant
		Extend => prior_indic
		Linker => if prior_indic == AfterConsonant or prior_indic == AfterLinker {
			AfterLinker
		} else {
			NoIndicContext
		}
		None => NoIndicContext
	}

	{
		started: Bool.True,
		cluster_start: if (broke_before) byte_start else machine.cluster_start,
		previous: current.gcb,
		ri_odd: next_ri_odd,
		emoji_context: next_emoji,
		indic_context: next_indic,
	}
}
