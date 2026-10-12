import cli.Cmd
import cli.Env
import cli.Monotonic
import cli.OsStr
import cli.Path
import cli.Stdout
import Ratchet
import Report
import Script

## Holds the allocation counts of `tests/allocations/main.roc` to the ceilings
## in `tests/allocations.json`.
Allocations := [].{

	## Build the counting target with `roc`, run each case, and print its
	## count beside its ceiling. Fails if any case allocates more than that.
	check! : Script.Command => Try({}, _)
	check! = |roc| {
		cases = match Ratchet.parse(Path.read_utf8!(ceilings)?) {
			Ok(parsed) => parsed
			Err(InvalidRatchets) => return Script.fail!("${Path.display(ceilings)} must list cases, each with a name, operation, repeat and ceiling")
		}
		steps = Env.with_temp_dir!(|build| measure!(roc, cases, build))?
		Stdout.line!("")?
		if Report.passed(steps) {
			Script.pass!("${cases.len().to_str()} allocation ceilings hold")
		} else {
			Script.fail!("an allocation ceiling was exceeded: find the copy that crept in, or raise the ceiling in ${Path.display(ceilings)} and say why")
		}
	}
}

ceilings : Path
ceilings = "tests/allocations.json"

measure! = |roc, cases, build| {
	executable = Path.join(build, "allocations")
	# The roc-fuzz platform is what counts allocations; nothing is fuzzed.
	roc.run!(["build", "--fuzz", "tests/allocations/main.roc", OsStr.from_str("--output=${Path.display(executable)}"), "--no-cache"])?
	var $steps = []
	var $index = 0
	for case in cases {
		$index = $index + 1
		begun = Monotonic.now!()
		input = Path.join(build, "input")
		match Ratchet.input(case) {
			Ok(bytes) => Path.write_bytes!(input, bytes)?
			Err(UnknownOperation(operation)) => return Script.fail!("${Path.display(ceilings)} [${case.name}]: tests/allocations/main.roc has no operation named ${operation}")
		}
		# The target reports its count by crashing with it, so a failing
		# exit code is expected and the count is what is checked.
		output = Cmd.new(Path.to_os_str(executable))
			.args(["replay", Path.to_os_str(input)])
			.stdout(Capture)
			.stderr(Capture)
			.timeout_ms(60_000)
			.run!()
			.map_err(|err| CommandRunFailed(Path.display(executable), err))?
		printed = "${Str.from_utf8_lossy(output.stdout_bytes)}${Str.from_utf8_lossy(output.stderr_bytes)}"
		count = match Ratchet.measured(printed) {
			Ok(value) => value
			Err(NoMeasurement) => return Script.fail!("${case.name}: the target reported no allocation count\n${printed}")
		}
		(outcome, numbers) = match Ratchet.verdict(case, count) {
			Over(text) => (Fail, text)
			Within(text) => (Pass, text)
			Under(text) => (Pass, text)
		}
		step = { name: "${case.name}: ${numbers}", outcome, ms: Report.elapsed_ms(begun, Monotonic.now!()) }
		Stdout.line!(Report.line({ index: $index, total: cases.len(), width: 0, colour: Bool.False }, step))?
		$steps = $steps.append(step)
	}
	Ok($steps)
}
