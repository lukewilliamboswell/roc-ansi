import cli.Cmd
import cli.Env
import cli.Monotonic
import cli.OsStr
import cli.Path
import cli.Stderr
import cli.Stdout
import cli.Tcp
import Files
import Loopback
import Report
import Script
import Spec

## The driver for the examples: one build of each, then every recorded case.
##
## It runs the working tree's examples, a candidate bundle's and a published
## archive's alike, so all three are held to the same recorded output.
Examples := [].{

	## How the examples reach their package. `Direct` leaves Roc to resolve the
	## dependency declared in each header. `Served(server)` also answers its
	## requests from a `Loopback` server while each command runs.
	Source : [Direct, Served({ listener : Tcp.Listener, bytes : List(U8), url : Str })]

	## What to do with the examples in `directory`.
	##
	## `expected` is the specification to compare with, or `ExitCodeOnly` for an
	## archive published before releases carried one. `Update` rewrites that
	## specification from what the examples print, in place of comparing.
	## `roc_args` are added to every `roc check` and `roc build`.
	Options : {
		directory : Path,
		source : Source,
		expected : [Recorded(Path), ExitCodeOnly],
		mode : [Compare, Update],
		roc_args : List(OsStr),
	}

	## Check and build every example once, run each case against the built
	## executable, and report every step. Fails after the summary if any step
	## failed, so one run shows everything that is wrong.
	run! : Script.Command, Options => Try({}, _)
	run! = |roc, options| {
		started = Monotonic.now!()
		colour = colour!()?
		names = Files.direct_roc_files!(options.directory)?.map_try(Script.file_name)?
		examples = load!(options, names.map(|name| "examples/${name}"))?
		if examples.is_empty() {
			return Script.fail!("${Path.display(options.directory)} must hold at least one application")
		}

		done = Env.with_temp_dir!(|build| execute!(roc, options, examples, colour, build))?

		Stdout.line!("")?
		if !done.failures.is_empty() {
			Stdout.line!("Failed\n${Str.join_with(done.failures, "\n")}\n")?
		}
		Stdout.line!(Report.summary(done.steps, Report.elapsed_ms(started, Monotonic.now!())))?
		if !Report.passed(done.steps) {
			return Script.fail!("${done.failures.len().to_str()} steps failed in ${Path.display(options.directory)}")
		}
		match (options.mode, options.expected) {
			(Update, Recorded(spec_path)) => {
				rendered = Spec.render(done.updated)
				if Path.read_utf8!(spec_path)? == rendered {
					Script.info!("UNCHANGED", Path.display(spec_path))
				} else {
					Path.write_utf8!(spec_path, rendered)?
					Script.info!("UPDATED", Path.display(spec_path))
				}
			}
			_ => Ok({})
		}
	}
}

# Build every example into `build`, then run every case. Each step is printed
# as it finishes and returned for the summary.
execute! = |roc, options, examples, colour, build| {
	var $steps = []
	var $failures = []
	var $updated = []
	Stdout.line!("Building ${examples.len().to_str()} examples with --opt=dev")?
	labels = examples.map(|example| "build ${Files.stem(example.path.drop_prefix("examples/"))}")
	var $built = []
	var $index = 0
	for example in examples {
		$index = $index + 1
		name = example.path.drop_prefix("examples/")
		executable = Path.join(build, Files.stem(name))
		begun = Monotonic.now!()
		problem = build!(roc, options, name, executable)?
		step = { name: "build ${Files.stem(name)}", outcome: if problem == "" Pass else Fail, ms: Report.elapsed_ms(begun, Monotonic.now!()) }
		Stdout.line!(Report.line({ index: $index, total: examples.len(), width: width(labels), colour }, step))?
		$steps = $steps.append(step)
		if problem == "" {
			$built = $built.append(example.path)
		} else {
			$failures = $failures.append("  ${step.name}: ${problem}")
		}
	}

	total = examples.map(|example| example.cases.len()).sum()
	case_labels = examples.join_map(|example| example.cases.map(|case| Spec.label(example, case)))
	Stdout.line!("\nRunning ${total.to_str()} cases")?
	$index = 0
	for example in examples {
		executable = Path.join(build, Files.stem(example.path.drop_prefix("examples/")))
		var $cases = []
		for case in example.cases {
			$index = $index + 1
			begun = Monotonic.now!()
			result = if $built.contains(example.path) {
				case!(options, executable, case)?
			} else {
				{ case, outcome: Fail, problem: "its example did not build" }
			}
			step = { name: Spec.label(example, case), outcome: result.outcome, ms: Report.elapsed_ms(begun, Monotonic.now!()) }
			Stdout.line!(Report.line({ index: $index, total, width: width(case_labels), colour }, step))?
			$steps = $steps.append(step)
			$cases = $cases.append(result.case)
			if result.outcome == Fail {
				$failures = $failures.append("  ${step.name}: ${result.problem}")
			}
		}
		$updated = $updated.append({ path: example.path, cases: $cases })
	}
	Ok({ steps: $steps, failures: $failures, updated: $updated })
}

# The specification to run: the recorded one, checked against the examples
# that exist, or one case per example that only requires it to exit with 0.
load! : Examples.Options, List(Str) => Try(List(Spec.App), _)
load! = |options, paths|
	match options.expected {
		ExitCodeOnly => Ok(paths.map(|path| { path, cases: [{ name: "exits with 0", args: Err(Missing), stdin: Err(Missing), exit_code: Err(Missing), stdout: Err(Missing), skip: Err(Missing) }] }))
		Recorded(spec_path) => {
			examples = match Spec.parse(Path.read_utf8!(spec_path)?) {
				Ok(parsed) => parsed
				Err(InvalidSpec) => return Script.fail!("${Path.display(spec_path)} is not a specification of the examples")
			}
			# A case being recorded for the first time has no output yet.
			problems = Spec.problems(examples, paths).keep_if(|problem| options.mode == Compare or !problem.ends_with(": the expected stdout is required"))
			if problems.is_empty() {
				Ok(examples)
			} else {
				Script.fail!("${Path.display(spec_path)} does not describe the examples in ${Path.display(options.directory)}:\n${Str.join_with(problems, "\n")}")
			}
		}
	}

# Check an example and build it once, for every case to run. Returns what went
# wrong, or "" when the executable is ready.
build! : Script.Command, Examples.Options, Str, Path => Try(Str, _)
build! = |roc, options, name, executable| {
	source = OsStr.from_str(name)
	steps = [
		["check", source, "--no-cache"],
		["build", source, "--opt=dev", OsStr.from_str("--output=${Path.display(executable)}"), "--no-cache"],
	]
	var $problem = ""
	for args in steps {
		if $problem == "" {
			command = roc.cmd(args.concat(options.roc_args)).cwd(options.directory)
			label = Str.join_with([roc.program].concat(args).concat(options.roc_args).map(OsStr.display), " ")
			output = match options.source {
				Direct => captured!(label, command)?
				Served(server) => Loopback.run!(server, command)?
			}
			$problem = match output.status {
				Exited(0) => ""
				_ => "${label} failed\n${Str.from_utf8_lossy(output.stdout_bytes)}${Str.from_utf8_lossy(output.stderr_bytes)}"
			}
		}
	}
	Ok($problem)
}

# Run one case against a built example. The case comes back as it should be
# recorded, which differs from the given one only when updating.
case! : Examples.Options, Path, Spec.Case => Try({ case : Spec.Case, outcome : Report.Outcome, problem : Str }, _)
case! = |options, executable, case| {
	match case.skip {
		Ok({ reason, issue }) => return Ok({ case, outcome: Skip("${reason}, ${issue}"), problem: "" })
		Err(Missing) => {}
	}
	command = Cmd.new(Path.to_os_str(executable))
		.args((case.args ?? []).map(OsStr.from_str))
		.cwd(options.directory)
		.stdin(Bytes(Str.to_utf8(case.stdin ?? "")))
		.stdout(Capture)
		.stderr(Capture)
		.timeout_ms(10_000)
	output = match command.run!() {
		Ok(finished) => finished
		Err(Timeout(_)) => return Ok({ case, outcome: Fail, problem: "still running after 10_000ms" })
		Err(err) => return Err(CommandRunFailed(Path.display(executable), err))
	}
	code = match output.status {
		Exited(value) => value
		Signaled(signal) => return Ok({ case, outcome: Fail, problem: "terminated by signal ${signal.to_str()}" })
	}
	actual = match Str.from_utf8(output.stdout_bytes) {
		Ok(text) => text
		Err(_) => return Ok({ case, outcome: Fail, problem: "stdout is not UTF-8" })
	}
	match options.mode {
		Update => Ok({ case: { ..case, stdout: Ok(actual), exit_code: if code == 0 Err(Missing) else Ok(code) }, outcome: Pass, problem: "" })
		Compare => {
			wanted_code = case.exit_code ?? 0
			problem = if code != wanted_code {
				"expected exit code ${wanted_code.to_str()}, got ${code.to_str()}\n${Str.from_utf8_lossy(output.stderr_bytes)}"
			} else {
				match case.stdout {
					Ok(wanted) if wanted != actual => "unexpected stdout\n    expected ${visible(wanted)}\n    actual   ${visible(actual)}"
					_ => ""
				}
			}
			Ok({ case, outcome: if problem == "" Pass else Fail, problem })
		}
	}
}

# Colour is an aid, never the only signal, and is left out when nobody is
# looking at a terminal or `NO_COLOR` asks for that.
colour! = || {
	if Script.env_or!("NO_COLOR", "")? != "" {
		return Ok(Bool.False)
	}
	# `test` inherits this script's standard output, and -t asks whether it is a terminal.
	code = Cmd.new("test").args(["-t", "1"]).exec_exit_code!().map_err(|_| CommandRunFailed("test -t 1", Unavailable))?
	Ok(code == 0)
}

# Escape sequences are what the examples print, so show them instead of letting
# the terminal act on them.
visible = |text| Str.replace_each(Str.inspect(text), "\u(001b)", "\\e")

width = |labels| labels.map(|label| Str.to_utf8(label).len()).max() ?? 0

captured! = |label, command|
	command
		.stdout(Capture)
		.stderr(Capture)
		.run!()
		.map_err(|err| CommandRunFailed(label, err))
