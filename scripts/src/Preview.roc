import cli.Duration
import cli.Path
import cli.Stdout
import cli.Tcp
import Html

## A small static file server for previewing the assembled site.
##
## It serves under the same base path GitHub Pages uses, because older
## archived docs embed `<base href="/roc-ansi/…">`.
Preview := [].{

	## Serve the directory `site` on 127.0.0.1 at `port` until interrupted.
	## Port zero picks a free port.
	serve! = |site, port| {
		listener = Tcp.listen!("127.0.0.1", port, Duration.seconds(5))?
		bound = listener.local_port!()?
		Stdout.line!("Serving the site at http://127.0.0.1:${bound.to_str()}${Html.base_path}/ (Ctrl-C to stop)")?
		# Keep the result reachable while serving until interrupted.
		var $serving = Bool.True
		while $serving {
			match listener.accept!({ accept_timeout: After(Duration.seconds(1)), io_timeout: Duration.seconds(5) }) {
				Ok(stream) =>
				# A dropped connection must not stop the preview.
					match answer!(stream.with_line_limit(8_192), site) {
						Ok(line) => Stdout.line!(line)?
						Err(_) => Stdout.line!("request failed")?
					}
				Err(TcpErr(TimedOut)) => {}
				Err(err) => return Err(PreviewServerFailed(err))
			}
		}
		Ok({})
	}
}

answer! = |stream, site| {
	request = stream.read_line!()?.trim()
	skip_headers!(stream, 100)?
	target = match Str.split_on(request, " ") {
		["GET", value, ..] | ["HEAD", value, ..] => value
		_ => {
			send!(stream, "405 Method Not Allowed", "text/plain; charset=utf-8", [], Str.to_utf8("method not allowed\n"))?
			return Ok("405 ${request}")
		}
	}
	path = match Str.split_first(target, "?") {
		Ok({ before, .. }) => before
		Err(_) => target
	}
	match Html.route(path) {
		Redirect(location) => {
			send!(stream, "302 Found", "text/plain; charset=utf-8", ["Location: ${location}"], [])?
			Ok("302 ${path}")
		}
		NotFound => not_found!(stream, path)
		File(relative) => {
			file = relative.fold(site, |parent, segment| Path.join(parent, segment))
			if Path.is_dir!(file)? {
				send!(stream, "302 Found", "text/plain; charset=utf-8", ["Location: ${path}/"], [])?
				Ok("302 ${path}")
			} else if Path.is_file!(file)? {
				send!(stream, "200 OK", content_type(Path.display(file)), [], Path.read_bytes!(file)?)?
				Ok("200 ${path}")
			} else {
				not_found!(stream, path)
			}
		}
	}
}

not_found! = |stream, path| {
	send!(stream, "404 Not Found", "text/plain; charset=utf-8", [], Str.to_utf8("not found\n"))?
	Ok("404 ${path}")
}

# Read to the blank line that ends the request headers, so the browser has
# nothing unread when the connection closes.
skip_headers! = |stream, remaining|
	if remaining == 0 {
		Ok({})
	} else {
		match stream.read_line!()?.trim() {
			"" => Ok({})
			_ => skip_headers!(stream, remaining - 1)
		}
	}

send! = |stream, status, kind, extra_headers, body| {
	headers = ["HTTP/1.1 ${status}", "Content-Type: ${kind}", "Content-Length: ${body.len().to_str()}", "Connection: close"]
		.concat(extra_headers)
		.concat(["", ""])
	stream.write_utf8!(Str.join_with(headers, "\r\n"))?
	stream.with_timeout(Duration.seconds(30)).write_bytes!(body)
}

content_type = |file_name|
	if file_name.ends_with(".html") {
		"text/html; charset=utf-8"
	} else if file_name.ends_with(".css") {
		"text/css; charset=utf-8"
	} else if file_name.ends_with(".js") {
		"text/javascript; charset=utf-8"
	} else if file_name.ends_with(".svg") {
		"image/svg+xml"
	} else if file_name.ends_with(".png") {
		"image/png"
	} else if file_name.ends_with(".wasm") {
		"application/wasm"
	} else if file_name.ends_with(".json") {
		"application/json"
	} else {
		"application/octet-stream"
	}
