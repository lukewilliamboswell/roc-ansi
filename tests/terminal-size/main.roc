app [main!] {
	ansi: "../../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.28.1/7brgwR8YUqfeGrkdfF1V4GPPN7DnP7ftqub9KcrTEZtr.tar.zst",
}

import ansi.ANSI
import pf.Env
import pf.Path
import pf.Stdout

# Files provide deterministic, independent state for the injected I/O callbacks.
# One-byte reads exercise every split boundary through the public query helper.
main! = |_args| Env.with_temp_dir!(
	|directory| {
		input = Path.join(directory, "input")
		output = Path.join(directory, "output")
		for chunk_size in [1, 4096] {
			for report in [Str.to_utf8("\u(001b)[8;24;80t"), [155].concat(Str.to_utf8("8;24;80t"))] {
				Path.write_bytes!(input, ['x'].concat(report).append('y'))?
				result = ANSI.query_screen_size!({
					write!: |text| Path.write_utf8!(output, text),
					read!: || {
						remaining = Path.read_bytes!(input)?
						Path.write_bytes!(input, remaining.drop_first(chunk_size))?
						Ok(remaining.take_first(chunk_size))
					},
				})?
				if result.size != { width: 80, height: 24 } {
					crash "wrong dimensions"
				}
				if result.input.concat(Path.read_bytes!(input)?) != ['x', 'y'] {
					crash "unrelated input was lost or reordered"
				}
				if Path.read_utf8!(output)? != ANSI.screen_size_request {
					crash "wrong request"
				}
			}
		}

		# No extra read is needed once the report has arrived.
		result = ANSI.query_screen_size!({
			write!: |_| Ok({}),
			read!: || Ok(Str.to_utf8("\u(001b)[8;24;80t")),
		})?
		if result != { size: { width: 80, height: 24 }, input: [] } {
			crash "complete reply failed"
		}

		match ANSI.query_screen_size!({
			write!: |_| Err(WriteDenied),
			read!: || {
				crash "read after a failed write"
			},
		}) {
			Err(WriteFailed(WriteDenied)) => {}
			_ => crash "write error was lost"
		}
		match ANSI.query_screen_size!({ write!: |_| Ok({}), read!: || Err(TimedOut) }) {
			Err(ReadFailed(TimedOut, [])) => {}
			_ => crash "read error was lost"
		}
		match ANSI.query_screen_size!({ write!: |_| Ok({}), read!: || Ok([]) }) {
			Err(NoResponse([])) => {}
			_ => crash "empty input did not stop"
		}
		match ANSI.query_screen_size!({ write!: |_| Ok({}), read!: || Ok(Str.to_utf8("\u(001b)[8;0;80t")) }) {
			Err(InvalidResponse(bytes)) if bytes == Str.to_utf8("\u(001b)[8;0;80t") => {}
			_ => crash "invalid report was accepted or discarded"
		}
		match ANSI.query_screen_size!({ write!: |_| Ok({}), read!: || Ok(List.repeat('x', 1024)) }) {
			Err(InputLimitExceeded(bytes)) if bytes.len() == 5120 => {}
			_ => crash "input limit did not stop the query"
		}

		# A read failure after partial input must give every consumed byte back.
		Path.write_bytes!(input, Str.to_utf8("x\u(001b)[8;24;"))?
		match ANSI.query_screen_size!({
			write!: |_| Ok({}),
			read!: || {
				remaining = Path.read_bytes!(input)?
				Path.write_bytes!(input, [])?
				if (remaining.is_empty()) Err(TimedOut) else Ok(remaining)
			},
		}) {
			Err(ReadFailed(TimedOut, bytes)) if bytes == Str.to_utf8("x\u(001b)[8;24;") => {}
			_ => crash "partial input was lost on timeout"
		}
		Stdout.line!("PASS terminal-size query I/O, fragmentation, input preservation and failures")
	},
)
