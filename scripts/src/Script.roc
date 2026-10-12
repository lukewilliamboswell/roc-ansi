import cli.Cmd
import cli.Env
import cli.OsStr
import cli.Path
import cli.Stderr
import cli.Stdout

## Command, environment and reporting helpers shared by the scripts.
Script := [].{

	## A program the scripts start, kept with its name for readable logs.
	Command := { base : Cmd, program : OsStr }.{

		## Print the command, then run it with inherited output.
		run! : Command, List(OsStr) => Try({}, _)
		run! = |self, args| {
			Stdout.line!("+ ${Str.join_with([self.program].concat(args).map(OsStr.display), " ")}")?
			self.base.args(args).exec_cmd!()
		}

		## Run in `cwd` with `stdin` as input and return captured standard output.
		## Standard error is printed only when the command fails.
		capture! : Command, List(OsStr), Path, List(U8) => Try(List(U8), _)
		capture! = |self, args, cwd, stdin| {
			output = self.base
				.args(args)
				.cwd(cwd)
				.stdin(Bytes(stdin))
				.run!()
				.map_err(|err| CommandRunFailed(OsStr.display(self.program), err))?
			match output.status {
				Exited(0) => Ok(output.stdout_bytes)
				Exited(code) => {
					Stderr.write_bytes!(output.stderr_bytes)?
					Err(CommandExited(OsStr.display(self.program), code))
				}
				Signaled(signal) => {
					Stderr.write_bytes!(output.stderr_bytes)?
					Err(CommandSignaled(OsStr.display(self.program), signal))
				}
			}
		}

		## Like `capture!`, decoding standard output as UTF-8.
		capture_utf8! : Command, List(OsStr), Path => Try(Str, _)
		capture_utf8! = |self, args, cwd| {
			bytes = self.capture!(args, cwd, [])?
			Str.from_utf8(bytes).map_err(|_| CommandOutputNotUtf8(OsStr.display(self.program)))
		}

		## The same program with a Roc package cache of its own in `directory`.
		##
		## Roc keeps every package it has fetched, keyed by content hash, and
		## does not fetch it again. A test of whether a bundle can be fetched
		## and used must therefore start from an empty cache, or an earlier
		## run can make it pass without the bundle being reachable at all.
		with_empty_package_cache : Command, Path -> Command
		with_empty_package_cache = |self, directory| Command.{ base: self.base.env("XDG_CACHE_HOME", Path.to_os_str(directory)), program: self.program }

		## The underlying basic-cli command with `args` appended.
		cmd : Command, List(OsStr) -> Cmd
		cmd = |self, args| self.base.args(args)
	}

	## A command for a program name or path.
	command : OsStr -> Command
	command = |program| Command.{ base: Cmd.new(program), program }

	## The pinned tooling compiler. It runs scripts and their tests, and nothing else.
	roc_stable! : () => Try(Command, _)
	roc_stable! = || compiler!("ROC_STABLE", "roc-stable")

	## The compiler the package and examples are checked with: the `roc` on
	## PATH, which is meant to be the latest nightly. It is never the tooling
	## compiler.
	roc! : () => Try(Command, _)
	roc! = || Ok(Script.command("roc"))

	## A UTF-8 environment variable, or `fallback` when it is unset or empty.
	env_or! : OsStr, Str => Try(Str, _)
	env_or! = |name, fallback|
		match Env.var_str!(name) {
			Ok("") => Ok(fallback)
			Ok(value) => Ok(value)
			Err(VarNotFound(_)) => Ok(fallback)
			Err(_) => Err(UnreadableEnvironmentVariable(OsStr.display(name)))
		}

	## A UTF-8 environment variable that must be set and non-empty.
	env! : OsStr => Try(Str, _)
	env! = |name|
		match Script.env_or!(name, "")? {
			"" => {
				Stderr.line!("error: the ${OsStr.display(name)} environment variable is required")?
				Err(ScriptFailed)
			}
			value => Ok(value)
		}

	## Print a section heading.
	section! : Str => Try({}, _)
	section! = |title| Stdout.line!("\n== ${title}")

	## Print a passed check.
	pass! : Str => Try({}, _)
	pass! = |message| Stdout.line!("PASS ${message}")

	## Print a labelled note, such as `SKIP`.
	info! : Str, Str => Try({}, _)
	info! = |label, message| Stdout.line!("${label} ${message}")

	## Print an error and fail the script.
	fail! : Str => Try(_, _)
	fail! = |message| {
		Stderr.line!("error: ${message}")?
		Err(ScriptFailed)
	}

	## Fail unless `path` is an existing regular file.
	require_file! : Path => Try({}, _)
	require_file! = |path|
		if Path.is_file!(path)? {
			Ok({})
		} else {
			Script.fail!("file does not exist: ${Path.display(path)}")
		}

	## The final component of `path` as text.
	file_name : Path -> Try(Str, _)
	file_name = |path|
		Path.filename(path)
			.map_ok(Path.display)
			.map_err(|_| PathHasNoFileName(Path.display(path)))
}

compiler! = |variable, fallback|
	match Env.var!(variable) {
		Ok(value) => Ok(Script.command(value))
		Err(VarNotFound(_)) => Ok(Script.command(fallback))
		Err(_) => Err(UnreadableEnvironmentVariable(OsStr.display(variable)))
	}
