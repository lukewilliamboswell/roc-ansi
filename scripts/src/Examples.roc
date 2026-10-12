import cli.Cmd
import cli.Env
import cli.OsStr
import cli.Path
import cli.Stderr
import cli.Stdout
import cli.Tcp
import Files
import Loopback
import Script

## The checks every copy of the examples must pass: the working tree's, a
## candidate bundle's, and a published archive's.
Examples := [].{

	## How the examples reach their package. `Direct` leaves Roc to resolve the
	## dependency declared in each header. `Served(server)` also answers its
	## requests from a `Loopback` server while each command runs.
	Source : [Direct, Served({ listener : Tcp.Listener, bytes : List(U8), url : Str })]

	## Check every example in `directory`, run the tests in `tests.roc`, then
	## run each application both directly and as a built executable.
	exercise! : Script.Command, Path, Source => Try({}, _)
	exercise! = |roc, directory, source| {
		files = Files.direct_roc_files!(directory)?
		names = files.map_try(Script.file_name)?
		apps = names.keep_if(|name| name != "tests.roc")
		if apps.is_empty() or !names.contains("tests.roc") {
			return Script.fail!("${Path.display(directory)} must hold tests.roc and at least one application")
		}

		for name in names {
			roc!(roc, ["check", OsStr.from_str(name), "--no-cache"], directory, source)?
		}
		roc!(roc, ["test", "tests.roc", "--no-cache"], directory, source)?
		for name in apps {
			roc!(roc, [OsStr.from_str(name), "--no-cache"], directory, source)?
		}
		Env.with_temp_dir!(
			|build| {
				for name in apps {
					executable = Path.join(build, Files.stem(name))
					roc!(roc, ["build", OsStr.from_str(name), "--output=${Path.display(executable)}", "--no-cache"], directory, source)?
					label = Path.display(executable)
					Stdout.line!("+ ${label}")?
					finish!(label, captured!(label, Cmd.new(Path.to_os_str(executable)).cwd(directory))?)?
				}
				Ok({})
			},
		)?
		Script.pass!("${names.len().to_str()} examples in ${Path.display(directory)}")
	}
}

roc! : Script.Command, List(OsStr), Path, Examples.Source => Try({}, _)
roc! = |roc, args, directory, source| {
	label = Str.join_with([roc.program].concat(args).map(OsStr.display), " ")
	command = roc.cmd(args).cwd(directory)
	Stdout.line!("+ ${label}")?
	output = match source {
		Direct => captured!(label, command)?
		Served(server) => Loopback.run!(server, command)?
	}
	finish!(label, output)
}

captured! = |label, command|
	command
		.stdout(Capture)
		.stderr(Capture)
		.run!()
		.map_err(|err| CommandRunFailed(label, err))

# Example output is colourful and long, so it is shown only when a command fails.
finish! = |label, output|
	match output.status {
		Exited(0) => Ok({})
		_ => {
			Stdout.write_bytes!(output.stdout_bytes)?
			Stderr.write_bytes!(output.stderr_bytes)?
			Script.fail!("command failed: ${label}")
		}
	}
