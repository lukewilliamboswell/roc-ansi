import cli.Cmd
import cli.Path
import cli.Tcp
import Script

## Serves one package bundle from 127.0.0.1.
##
## Roc fetches a package dependency by URL while it compiles. Serving the exact
## archive a release would publish lets the examples be tested against it
## before any release exists.
Loopback := [].{

	## Read `bundle` and start listening on a free port. The result carries the
	## URL to put in an application header, and is what `run!` and `stop!` take.
	start! = |bundle| {
		bytes = Path.read_bytes!(bundle)?
		file_name = Script.file_name(bundle)?
		listener = Tcp.listen!("127.0.0.1", 0, 5_000)?
		port = listener.local_port!()?
		Ok({ listener, bytes, url: "http://127.0.0.1:${port.to_str()}/${file_name}" })
	}

	## Run `command` to completion with captured output, answering every
	## connection made in the meantime with the bundle.
	run! = |server, command| {
		child = command
			.stdout(Capture)
			.stderr(Capture)
			.spawn!()
			.map_err(|err| CommandSpawnFailed(err))?
		serve_until_exit!(child, server)
	}

	## Stop listening.
	stop! = |server| server.listener.close!()
}

# This process must answer the child's request and notice the child exiting,
# without threads. A short accept timeout alternates between the two.
serve_until_exit! = |child, server|
	match child.try_wait!().map_err(|err| CommandWaitFailed(err))? {
		[output, ..] => Ok(output)
		[] =>
			match server.listener.accept!(100) {
				Ok(stream) => {
					_ = stream.read_until!('\n', 65_536, 5_000)?
					stream.write_utf8!(response_headers(server.bytes.len()), 5_000)?
					stream.write!(server.bytes, 30_000)?
					serve_until_exit!(child, server)
				}
				Err(TcpListenErr(TimedOut)) => serve_until_exit!(child, server)
				Err(err) => Err(BundleServerFailed(err))
			}
	}

# HTTP separates header lines with CRLF.
response_headers = |content_length|
	Str.join_with(
		[
			"HTTP/1.1 200 OK",
			"Content-Type: application/octet-stream",
			"Content-Length: ${content_length.to_str()}",
			"Connection: close",
			"",
			"",
		],
		"\r\n",
	)
