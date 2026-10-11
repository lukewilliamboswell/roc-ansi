## Pure inspection and rewriting of the header of a Roc application or package.
Headers := [].{

	## Whether an app or package header declares a `roc` compiler pin.
	has_roc_pin : Str -> Bool
	has_roc_pin = |source| fields(source).any(|(name, _)| name == "roc")

	## The quoted source declared for the dependency named `shorthand`.
	dependency : Str, Str -> Try(Str, [MissingDependency(Str), DuplicateDependency(Str), InvalidDependency(Str)])
	dependency = |source, shorthand|
		match fields(source).keep_if(|(name, _)| name == shorthand) {
			[(_, value)] =>
				match Str.split_on(value, "\"") {
					[_, declared, ""] => Ok(declared)
					_ => Err(InvalidDependency(shorthand))
				}
			[] => Err(MissingDependency(shorthand))
			_ => Err(DuplicateDependency(shorthand))
		}

	## The same source with the dependency named `shorthand` pointing at
	## `replacement`. Nothing else changes, and the header must be formatted by
	## `roc fmt` so the field can be found exactly once.
	with_dependency : Str, Str, Str -> Try(Str, [MissingDependency(Str), DuplicateDependency(Str), InvalidDependency(Str), UnformattedDependency(Str)])
	with_dependency = |source, shorthand, replacement| {
		declared = Headers.dependency(source, shorthand)?
		match Str.split_first(source, "${shorthand}: \"${declared}\"") {
			Ok({ before, after }) if opens_header(before) => Ok("${before}${shorthand}: \"${replacement}\"${after}")
			_ => Err(UnformattedDependency(shorthand))
		}
	}
}

# Type modules have no header, so only a line that starts an app or package opens one.
fields = |source|
	match Str.split_first(header_onwards(Str.split_on(source, "\n")), "{") {
		Ok({ after, .. }) =>
			match Str.split_first(after, "}") {
				Ok({ before, .. }) => Str.split_on(before, ",").keep_oks(field)
				Err(_) => []
			}
		Err(_) => []
	}

# Whether `text` ends inside the braces of the header, before they close.
opens_header = |text| {
	header = header_onwards(Str.split_on(text, "\n"))
	header.contains("{") and !header.contains("}")
}

header_onwards = |lines|
	match lines {
		[line, ..] if line.starts_with("app ") or line.starts_with("package ") => Str.join_with(lines, "\n")
		[_, .. as rest] => header_onwards(rest)
		[] => ""
	}

field = |entry|
	match Str.split_first(entry, ":") {
		Ok({ before, after }) => Ok((before.trim(), after.trim()))
		Err(_) => Err(NotAField)
	}

example = "app [main!] {\n\tansi: \"../package/main.roc\",\n\tpf: platform \"https://example.com/cli.tar.zst\",\n}\n\nmain! = |_| { ansi: \"../package/main.roc\" }\n"

expect Headers.has_roc_pin("app [main!] { ansi: \"../package/main.roc\", roc: \"nightly-2026-10-09-258ab27\" }\n")
expect Headers.has_roc_pin("#!/usr/bin/env roc-stable\napp [main!] {\n\tcli: platform \"https://example.com/cli.tar.zst\",\n\troc : \"nightly-2026-10-09-258ab27\",\n}\n")
expect Headers.has_roc_pin("## Docs\npackage [ANSI] { roc: \"nightly-2026-10-09-258ab27\" }\n")
expect !Headers.has_roc_pin("package\n\t[\n\t\tANSI,\n\t]\n\t{}\n")
expect !Headers.has_roc_pin("app [main!] { ansi: \"../package/main.roc\" }\n\nmain! = |_| { roc: \"not a header\" }\n")
expect !Headers.has_roc_pin("Files := [].{\n\tpin = { roc: \"nightly\" }\n}\n")
expect !Headers.has_roc_pin("app [main!] { heroc: \"https://example.com/roc: x.tar.zst\" }\n")
expect Headers.dependency(example, "ansi") == Ok("../package/main.roc")
expect Headers.dependency(example, "pf") == Ok("https://example.com/cli.tar.zst")
expect Headers.dependency(example, "weaver") == Err(MissingDependency("weaver"))
expect Headers.dependency("app [main!] { ansi: \"a\", ansi: \"b\" }\n", "ansi") == Err(DuplicateDependency("ansi"))
expect Headers.with_dependency(example, "ansi", "https://example.com/abc.tar.zst") == Ok("app [main!] {\n\tansi: \"https://example.com/abc.tar.zst\",\n\tpf: platform \"https://example.com/cli.tar.zst\",\n}\n\nmain! = |_| { ansi: \"../package/main.roc\" }\n")
expect Headers.with_dependency(example, "weaver", "x") == Err(MissingDependency("weaver"))
expect Headers.with_dependency("app [main!] { ansi : \"../package/main.roc\" }\n", "ansi", "x") == Err(UnformattedDependency("ansi"))
expect Headers.with_dependency("# ansi: \"x\"\napp [main!] { ansi: \"x\" }\n", "ansi", "y") == Err(UnformattedDependency("ansi"))
