## Allocation ceilings for the operations a caller runs in a loop.
##
## `tests/allocations.json` records, for each case, the most allocations it
## may make. A ceiling is a ratchet: a run may come in under it, because a
## newer compiler may do better, and it is lowered when that happens so the
## gain cannot be lost quietly. Raising one is a decision to review.
Ratchet := [].{

	## One measured case: an operation of `tests/allocations/main.roc`, how
	## often to repeat it, and the most allocations that may take.
	Case : { name : Str, operation : Str, repeat : U8, ceiling : U64 }

	## Read the cases from the text of `tests/allocations.json`.
	parse : Str -> Try(List(Case), [InvalidRatchets])
	parse = |text| {
		ratchets : Try({ cases : List(Case) }, _)
		ratchets = Json.parse(text)
		match ratchets {
			Ok({ cases }) if !cases.is_empty() => Ok(cases)
			_ => Err(InvalidRatchets)
		}
	}

	## The input that makes the target run `case`: a byte for the operation,
	## then the number of repetitions.
	input : Case -> Try(List(U8), [UnknownOperation(Str)])
	input = |case|
		match case.operation {
			"insert" => Ok([0, case.repeat])
			"delete" => Ok([1, case.repeat])
			other => Err(UnknownOperation(other))
		}

	## The count in what the target printed, which it reports as
	## `ALLOCATIONS <count>`.
	measured : Str -> Try(U64, [NoMeasurement])
	measured = |output|
		match Str.split_first(output, "ALLOCATIONS ") {
			Ok({ after, .. }) =>
				match Str.split_first(after, " ") {
					Ok({ before, .. }) => U64.from_str(before).map_err(|_| NoMeasurement)
					Err(_) => Err(NoMeasurement)
				}
			Err(_) => Err(NoMeasurement)
		}

	## How a measured count stands against the ceiling of `case`, with the
	## two numbers side by side.
	verdict : Case, U64 -> [Over(Str), Within(Str), Under(Str)]
	verdict = |case, count| {
		numbers = "${count.to_str()} allocations, ceiling ${case.ceiling.to_str()}"
		if count > case.ceiling {
			Over(numbers)
		} else if count < case.ceiling {
			Under("${numbers}: lower the ceiling to ${count.to_str()}")
		} else {
			Within(numbers)
		}
	}
}

inserts : Ratchet.Case
inserts = { name: "100 inserts", operation: "insert", repeat: 100, ceiling: 310 }

expect Ratchet.parse("{ \"cases\": [{ \"name\": \"100 inserts\", \"operation\": \"insert\", \"repeat\": 100, \"ceiling\": 310 }] }") == Ok([inserts])
expect Ratchet.parse("{ \"cases\": [] }") == Err(InvalidRatchets) and Ratchet.parse("{ \"cases\": [{ \"name\": \"no ceiling\" }] }") == Err(InvalidRatchets)
expect Ratchet.input(inserts) == Ok([0, 100]) and Ratchet.input({ ..inserts, operation: "delete" }) == Ok([1, 100])
expect Ratchet.input({ ..inserts, operation: "sort" }) == Err(UnknownOperation("sort"))
expect Ratchet.measured("Running: input\n[roc crashed] ALLOCATIONS 310 for a document of 114 values\n==1== ERROR") == Ok(310)
expect Ratchet.measured("[roc crashed] index out of bounds") == Err(NoMeasurement) and Ratchet.measured("ALLOCATIONS many for") == Err(NoMeasurement)
expect Ratchet.verdict(inserts, 310) == Within("310 allocations, ceiling 310")
expect Ratchet.verdict(inserts, 311) == Over("311 allocations, ceiling 310")
expect Ratchet.verdict(inserts, 205) == Under("205 allocations, ceiling 310: lower the ceiling to 205")
