## Turning a release's notes into the body of its GitHub release.
##
## The notes are written by hand in `docs/releases/<version>.adoc`, as part of
## the manual. They cannot name the release's bundle URL, because it holds the
## hash of a bundle that does not exist until the release builds it. They say
## `{package-url}` instead, and the release fills it in.
Notes := [].{

	## What stands for the release's bundle URL in the notes.
	placeholder : Str
	placeholder = "{package-url}"

	## Render the AsciiDoc `source` as Markdown, with the placeholder replaced
	## by `package_url`. The notes must open with `title` and use the
	## placeholder, and must leave no other `{...-url}` unresolved.
	##
	## Only what release notes use is converted: headings, source blocks and
	## links. Paragraphs, lists and `code` read the same in both.
	render : Str, { title : Str, package_url : Str } -> Try(Str, [WrongTitle(Str), UnusedPlaceholder, UnresolvedPlaceholder(Str), UnclosedBlock])
	render = |source, { title, package_url }|
		match Str.split_on(source, "\n") {
			[first, .. as body] if first == title => {
				if !source.contains(Notes.placeholder) {
					return Err(UnusedPlaceholder)
				}
				lines = convert(body.map(|line| Str.replace_each(line, Notes.placeholder, package_url)), Prose, [])?
				match lines.keep_oks(unresolved) {
					[name, ..] => Err(UnresolvedPlaceholder(name))
					[] => Ok("${Str.join_with(lines, "\n").trim()}\n")
				}
			}
			[first, ..] => Err(WrongTitle(first))
			[] => Err(WrongTitle(""))
		}

	## The section that says what a release was built and tested with. No
	## header pins the package compiler, so this is where a release states it.
	compilers : { roc : Str, roc_stable : Str } -> Str
	compilers = |versions|
		Str.join_with(
			[
				"## Compilers",
				"",
				"- Package and examples built and tested with `roc` ${versions.roc}",
				"- Release tooling run with `roc-stable` ${versions.roc_stable}",
				"",
			],
			"\n",
		)
}

convert : List(Str), [Prose, Block], List(Str) -> Try(List(Str), [UnclosedBlock])
convert = |lines, state, out|
	match (state, lines) {
		(Prose, []) => Ok(out)
		(Block, []) => Err(UnclosedBlock)
		(Block, ["----", .. as rest]) => convert(rest, Prose, out.append("```"))
		(Block, [line, .. as rest]) => convert(rest, Block, out.append(line))
		(Prose, [declared, "----", .. as rest]) if declared.starts_with("[source") => convert(rest, Block, out.append("```${language(declared)}"))
		(Prose, ["----", .. as rest]) => convert(rest, Block, out.append("```"))
		(Prose, [line, .. as rest]) => convert(rest, Prose, out.append(links(heading(line))))
	}

# `[source,roc]` names its language second.
language = |declared|
	match Str.split_on(declared.drop_prefix("[").drop_suffix("]"), ",") {
		[_, name, ..] => name.trim()
		_ => ""
	}

# A release's notes are a chapter of the manual, so their sections start at `==`.
heading = |line|
	if line.starts_with("=== ") {
		"### ${line.drop_prefix("=== ")}"
	} else if line.starts_with("== ") {
		"## ${line.drop_prefix("== ")}"
	} else {
		line
	}

# AsciiDoc writes a link as `https://example.com[text]`.
links = |line|
	match Str.split_first(line, "https://") {
		Ok({ before, after }) =>
			match Str.split_first(after, "[") {
				Ok({ before: address, after: rest }) if !address.contains(" ") =>
					match Str.split_first(rest, "]") {
						Ok({ before: text, after: remainder }) => "${before}[${text}](https://${address})${links(remainder)}"
						Err(_) => line
					}
				_ => "${before}https://${links(after)}"
			}
		Err(_) => line
	}

# The name of a `{...-url}` placeholder still in `line`.
unresolved = |line|
	match Str.split_first(line, "-url}") {
		Ok({ before, .. }) =>
			match Str.split_last(before, "{") {
				Ok({ after, .. }) if !after.contains(" ") => Ok("{${after}-url}")
				_ => Err(Resolved)
			}
		Err(_) => Err(Resolved)
	}

notes = "= roc-ansi 0.14.0\n\nAdds streaming.\n\n== Use this release\n\n[source,roc]\n----\napp [main!] {\n\tansi: \"{package-url}\",\n}\n----\n\n=== Thanks\n\n* See https://example.com/a[the issue] and https://example.com/b[the fix].\n* Plain https://example.com stays.\n"

release = { title: "= roc-ansi 0.14.0", package_url: "https://example.com/Abc.tar.zst" }

expect Notes.render(notes, release) == Ok("Adds streaming.\n\n## Use this release\n\n```roc\napp [main!] {\n\tansi: \"https://example.com/Abc.tar.zst\",\n}\n```\n\n### Thanks\n\n* See [the issue](https://example.com/a) and [the fix](https://example.com/b).\n* Plain https://example.com stays.\n")
expect Notes.render(notes, { ..release, title: "= roc-ansi 0.15.0" }) == Err(WrongTitle("= roc-ansi 0.14.0"))
expect Notes.render("= roc-ansi 0.14.0\n\nNothing to install.\n", release) == Err(UnusedPlaceholder)
expect Notes.render("= roc-ansi 0.14.0\n\n{package-url} and {tzdb-url}\n", release) == Err(UnresolvedPlaceholder("{tzdb-url}"))
expect Notes.render("= roc-ansi 0.14.0\n\n{package-url}\n\n----\nnever closed\n", release) == Err(UnclosedBlock)
expect Notes.render("= roc-ansi 0.14.0\n\n----\n{package-url}\n----\n", release) == Ok("```\nhttps://example.com/Abc.tar.zst\n```\n")
expect Notes.render("", release) == Err(WrongTitle(""))
expect Notes.compilers({ roc: "nightly-2", roc_stable: "nightly-1" }).contains("with `roc` nightly-2\n- Release tooling run with `roc-stable` nightly-1\n")
