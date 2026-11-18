import Text

## What a test run prints: one line for each step as it finishes, then a
## summary that can be read without the lines above it.
Report := [].{

	## How a step ended. A skip carries its reason.
	Outcome : [Pass, Fail, Skip(Str)]

	## A finished step: a build or a case.
	Step : { name : Str, outcome : Outcome, ms : U64 }

	## Milliseconds between two readings of the monotonic clock, which counts
	## nanoseconds.
	elapsed_ms : U64, U64 -> U64
	elapsed_ms = |started, finished| (finished - started) // 1_000_000

	## A duration in milliseconds, with `_` between each group of three digits.
	## One unit throughout lets the eye compare lengths and spot the slow step.
	millis : U64 -> Str
	millis = |ms| "${separated(Str.to_utf8(ms.to_str()), [])}ms"

	## The line for step `index` of `total`, with names padded to `width`:
	##
	##     [ 3/20] render-wide-table ............ FAIL   1_204ms
	##
	## The word is always printed. `colour` only adds to it.
	line : { index : U64, total : U64, width : U64, colour : Bool }, Step -> Str
	line = |position, step| {
		count = position.total.to_str()
		name_len = Str.to_utf8(step.name).len()
		dots = Str.repeat(".", if (position.width > name_len) position.width - name_len + 3 else 3)
		prefix = " [${pad_left(position.index.to_str(), Str.to_utf8(count).len())}/${count}] ${step.name} ${dots} "
		match step.outcome {
			Pass => "${prefix}${word("PASS", "32", position.colour)} ${pad_left(Report.millis(step.ms), 11)}"
			Fail => "${prefix}${word("FAIL", "31", position.colour)} ${pad_left(Report.millis(step.ms), 11)}"
			Skip(reason) => "${prefix}${word("SKIP", "33", position.colour)} ${Str.repeat(" ", 11)}  ${reason}"
		}
	}

	## Whether no step failed. Skips alone do not fail a run.
	passed : List(Step) -> Bool
	passed = |steps| !steps.any(|step| step.outcome == Fail)

	## The closing lines: every skip with its reason, the counts, and the
	## slowest steps. Failures are printed by the caller, which has their detail.
	summary : List(Step), U64 -> Str
	summary = |steps, total_ms| {
		skipped = steps.keep_oks(
			|step|
				match step.outcome {
					Skip(reason) => Ok("  ${step.name}: ${reason}")
					_ => Err(NotSkipped)
				},
		)
		failed = steps.count_if(|step| step.outcome == Fail)
		passes = steps.count_if(|step| step.outcome == Pass)
		slowest = List.sort_with(steps, |left, right| if (left.ms > right.ms) Before else if (left.ms < right.ms) After else Text.compare(left.name, right.name))
			.take_first(3)
			.map(|step| "${step.name} ${Report.millis(step.ms)}")
		Str.join_with(
			(if (skipped.is_empty()) [] else ["Skipped"].concat(skipped).append(""))
				.concat([
					"Summary: ${passes.to_str()} passed, ${failed.to_str()} failed, ${skipped.len().to_str()} skipped in ${Report.millis(total_ms)}",
					"Slowest: ${Str.join_with(slowest, ", ")}",
				]),
			"\n",
		)
	}
}

word = |text, code, colour| if (colour) "\u(001b)[${code}m${text}\u(001b)[0m" else text

pad_left = |text, width| {
	len = Str.to_utf8(text).len()
	if (width > len) "${Str.repeat(" ", width - len)}${text}" else text
}

# Walk the digits from the right, putting `_` before each complete group of three.
separated = |digits, grouped|
	match digits {
		[.. as rest, a, b, c] if !rest.is_empty() => separated(rest, ['_', a, b, c].concat(grouped))
		_ => Str.from_utf8_lossy(digits.concat(grouped))
	}

steps = [
	{ name: "build animals", outcome: Pass, ms: 6_870 },
	{ name: "animals", outcome: Pass, ms: 12 },
	{ name: "colors", outcome: Fail, ms: 1_204 },
	{ name: "menu", outcome: Skip("compiler bug, roc-lang/roc#1234"), ms: 0 },
]

expect Report.elapsed_ms(1_000_000, 13_999_999) == 12
expect Report.millis(0) == "0ms" and Report.millis(12) == "12ms" and Report.millis(999) == "999ms"
expect Report.millis(1_204) == "1_204ms" and Report.millis(10_000) == "10_000ms" and Report.millis(1_234_567) == "1_234_567ms"
expect Report.line({ index: 3, total: 20, width: 8, colour: Bool.False }, { name: "colors", outcome: Fail, ms: 1_204 }) == " [ 3/20] colors ..... FAIL     1_204ms"
expect Report.line({ index: 12, total: 20, width: 8, colour: Bool.False }, { name: "animals", outcome: Pass, ms: 12 }) == " [12/20] animals .... PASS        12ms"
expect Report.line({ index: 1, total: 4, width: 4, colour: Bool.False }, { name: "menu", outcome: Skip("needs a terminal"), ms: 0 }) == " [1/4] menu ... SKIP              needs a terminal"
expect Report.line({ index: 1, total: 1, width: 1, colour: Bool.True }, { name: "a", outcome: Pass, ms: 1 }) == " [1/1] a ... \u(001b)[32mPASS\u(001b)[0m         1ms"
expect !Report.passed(steps) and Report.passed(steps.keep_if(|step| step.name != "colors")) and Report.passed([])
expect Report.summary(steps, 10_312) == "Skipped\n  menu: compiler bug, roc-lang/roc#1234\n\nSummary: 2 passed, 1 failed, 1 skipped in 10_312ms\nSlowest: build animals 6_870ms, colors 1_204ms, animals 12ms"
expect Report.summary([{ name: "a", outcome: Pass, ms: 5 }], 5) == "Summary: 1 passed, 0 failed, 0 skipped in 5ms\nSlowest: a 5ms"
