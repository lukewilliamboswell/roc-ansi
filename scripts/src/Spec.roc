## The expected-output specification of the examples, `tests/spec.json`.
##
## It lists every example with the cases to run it with: the arguments, the
## standard input, and the exact output and exit code expected. The same file
## travels in each release's examples archive, so a release is always compared
## with what it printed when it was published.
Spec := [].{

	## Why a case is not run. Both fields are required, so a skip always says
	## what is broken and where that is tracked.
	Skip : { reason : Str, issue : Str }

	## One run of an example. Fields left out of the JSON are `Err(Missing)`:
	## no arguments, no input, exit code 0.
	Case : {
		name : Str,
		args : Try(List(Str), [Missing]),
		stdin : Try(Str, [Missing]),
		exit_code : Try(I32, [Missing]),
		stdout : Try(Str, [Missing]),
		skip : Try(Skip, [Missing]),
	}

	## An example, by its path from the repository root, and its cases.
	App : { path : Str, cases : List(Case) }

	## Read the specification from the text of `tests/spec.json`.
	parse : Str -> Try(List(App), [InvalidSpec])
	parse = |text| {
		spec : Try({ apps : List(App) }, _)
		spec = Json.parse(text)
		match spec {
			Ok({ apps }) => Ok(apps)
			Err(_) => Err(InvalidSpec)
		}
	}

	## Everything wrong with `apps` as the specification of the examples at
	## `paths`. An empty list means it can be run.
	problems : List(App), List(Str) -> List(Str)
	problems = |apps, paths| {
		specified = apps.map(|example| example.path)
		missing = paths.keep_if(|path| !specified.contains(path)).map(|path| "${path}: no cases are recorded for this example")
		extra = specified.keep_if(|path| !paths.contains(path)).map(|path| "${path}: cases are recorded for an example that does not exist")
		repeated = specified.keep_if(|path| specified.count_if(|other| other == path) != 1).map(|path| "${path}: listed more than once")
		missing.concat(extra).concat(repeated).concat(apps.join_map(app_problems))
	}

	## The specification as the text of `tests/spec.json`: one line per value,
	## so a change in expected output is a diff a reviewer can read.
	render : List(App) -> Str
	render = |apps| {
		compact = Json.to_str({ apps: apps })
		"${Str.from_utf8_lossy(indent(Str.to_utf8(compact), 0, Outside, []))}\n"
	}

	## The label a case is reported under.
	label : App, Case -> Str
	label = |example, case| {
		stem = example.path.drop_prefix("examples/").drop_suffix(".roc")
		if example.cases.len() == 1 stem else "${stem} [${case.name}]"
	}
}

app_problems : Spec.App -> List(Str)
app_problems = |example|
	(if example.cases.is_empty() ["${example.path}: at least one case is required"] else [])
		.concat(example.cases.join_map(|case| case_problems(example, case)))

case_problems : Spec.App, Spec.Case -> List(Str)
case_problems = |example, case| {
	at = "${example.path} [${case.name}]"
	name = if case.name == "" or example.cases.count_if(|other| other.name == case.name) != 1 ["${at}: every case needs a unique, non-empty name"] else []
	output = if case.stdout.is_err() and case.skip.is_err() ["${at}: the expected stdout is required"] else []
	skip = match case.skip {
		Ok({ reason, issue }) =>
			(if reason == "" ["${at}: a skip needs a reason"] else [])
				.concat(if issue.starts_with("https://") [] else ["${at}: a skip needs a link to the issue that tracks it"])
		Err(Missing) => []
	}
	name.concat(output).concat(skip)
}

# Json.to_str writes everything on one line. Break after each `{`, `[` and `,`
# and before each `}` and `]` that are not inside a string, indenting by depth.
indent : List(U8), U64, [Inside, Outside], List(U8) -> List(U8)
indent = |bytes, depth, state, out|
	match (state, bytes) {
		(_, []) => out
		(Inside, ['\\', escaped, .. as rest]) => indent(rest, depth, Inside, out.append('\\').append(escaped))
		(Inside, ['"', .. as rest]) => indent(rest, depth, Outside, out.append('"'))
		(Inside, [byte, .. as rest]) => indent(rest, depth, Inside, out.append(byte))
		(Outside, ['"', .. as rest]) => indent(rest, depth, Inside, out.append('"'))
		(Outside, ['{', '}', .. as rest]) => indent(rest, depth, Outside, out.concat(['{', '}']))
		(Outside, ['[', ']', .. as rest]) => indent(rest, depth, Outside, out.concat(['[', ']']))
		(Outside, ['{', .. as rest]) => indent(rest, depth + 1, Outside, new_line(out.append('{'), depth + 1))
		(Outside, ['[', .. as rest]) => indent(rest, depth + 1, Outside, new_line(out.append('['), depth + 1))
		(Outside, ['}', .. as rest]) => indent(rest, depth - 1, Outside, new_line(out, depth - 1).append('}'))
		(Outside, [']', .. as rest]) => indent(rest, depth - 1, Outside, new_line(out, depth - 1).append(']'))
		(Outside, [',', .. as rest]) => indent(rest, depth, Outside, new_line(out.append(','), depth))
		(Outside, [':', .. as rest]) => indent(rest, depth, Outside, out.concat([':', ' ']))
		(Outside, [byte, .. as rest]) => indent(rest, depth, Outside, out.append(byte))
	}

new_line = |out, depth| out.append('\n').concat(List.repeat(' ', depth * 2))

case : Spec.Case
case = { name: "default", args: Err(Missing), stdin: Err(Missing), exit_code: Err(Missing), stdout: Ok("a, \"b\"\n"), skip: Err(Missing) }

colors : Spec.App
colors = { path: "examples/colors.roc", cases: [case] }

rendered = "{\n  \"apps\": [\n    {\n      \"cases\": [\n        {\n          \"name\": \"default\",\n          \"stdout\": \"a, \\\"b\\\"\\n\"\n        }\n      ],\n      \"path\": \"examples/colors.roc\"\n    }\n  ]\n}\n"

expect Spec.render([colors]) == rendered
expect Spec.parse(rendered) == Ok([colors])
expect Spec.parse("{ \"apps\": 1 }") == Err(InvalidSpec) and Spec.parse("") == Err(InvalidSpec)
expect Spec.render([{ path: "examples/a.roc", cases: [{ ..case, args: Ok([]), stdout: Ok("\u(001b)[0m{[,]}") }] }]).contains("\"args\": [],\n          \"name\": \"default\",\n          \"stdout\": \"\\u001b[0m{[,]}\"\n")
expect Spec.problems([colors], ["examples/colors.roc"]) == []
expect Spec.problems([colors], ["examples/colors.roc", "examples/menu.roc"]) == ["examples/menu.roc: no cases are recorded for this example"]
expect Spec.problems([colors], []) == ["examples/colors.roc: cases are recorded for an example that does not exist"]
expect Spec.problems([{ path: "examples/colors.roc", cases: [] }], ["examples/colors.roc"]) == ["examples/colors.roc: at least one case is required"]
expect Spec.problems([{ path: "examples/colors.roc", cases: [case, case] }], ["examples/colors.roc"]).contains("examples/colors.roc [default]: every case needs a unique, non-empty name")
expect Spec.problems([{ path: "examples/colors.roc", cases: [{ ..case, stdout: Err(Missing) }] }], ["examples/colors.roc"]) == ["examples/colors.roc [default]: the expected stdout is required"]
expect Spec.problems([{ path: "examples/colors.roc", cases: [{ ..case, skip: Ok({ reason: "", issue: "" }) }] }], ["examples/colors.roc"]) == ["examples/colors.roc [default]: a skip needs a reason", "examples/colors.roc [default]: a skip needs a link to the issue that tracks it"]
expect Spec.problems([{ path: "examples/colors.roc", cases: [{ ..case, stdout: Err(Missing), skip: Ok({ reason: "compiler bug", issue: "https://github.com/roc-lang/roc/issues/1" }) }] }], ["examples/colors.roc"]) == []
expect Spec.label(colors, case) == "colors" and Spec.label({ path: "examples/colors.roc", cases: [case, { ..case, name: "wide" }] }, case) == "colors [default]"
