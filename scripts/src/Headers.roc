## Pure inspection of the header of a Roc application or package.
Headers := [].{

	## Whether an app or package header declares a `roc` compiler pin.
	has_roc_pin : Str -> Bool
	has_roc_pin = |source| fields(source).any(|(name, _)| name == "roc")

	## The compiler release named by the `roc` field of an app or package header.
	roc_pin : Str -> Try(Str, [MissingDependency(Str), DuplicateDependency(Str), InvalidDependency(Str)])
	roc_pin = |source| Headers.dependency(source, "roc")

	## Whether `source` is an application, which has an `app` header.
	is_app : Str -> Bool
	is_app = |source| header_onwards(Str.split_on(source, "\n")).starts_with("app ")

	## The release tag that the text of `Blueprint.roc` names as `roc-stable`.
	stable_tag : Str -> Try(Str, [NoStableCompiler])
	stable_tag = |blueprint| {
		# Whitespace may change when roc fmt wraps the Fetch declaration.
		lines = Str.split_on(blueprint, "\n").map(|line| line.trim()).keep_if(|line| !line.starts_with("#"))
		compact = Str.join_with(Str.split_on(Str.join_with(lines, ""), " "), "")
		match Str.split_on(compact, "Fetch(\"roc-stable\",Recipes.roc_nightly(\"") {
			[_, after] =>
				match Str.split_first(after, "\"") {
					Ok({ before, .. }) if before != "" => Ok(before)
					_ => Err(NoStableCompiler)
				}
			_ => Err(NoStableCompiler)
		}
	}

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
expect Headers.roc_pin("#!/usr/bin/env roc-stable\napp [main!] {\n\tcli: platform \"https://example.com/cli.tar.zst\",\n\troc: \"nightly-2026-10-09-258ab27\",\n}\n") == Ok("nightly-2026-10-09-258ab27")
expect Headers.roc_pin(example) == Err(MissingDependency("roc"))
expect Headers.is_app(example) and Headers.is_app("#!/usr/bin/env roc-stable\napp [main!] {}\n")
expect !Headers.is_app("package [ANSI] {}\n") and !Headers.is_app("Files := [].{\n\tapp = 1\n}\n")
stable_declaration = "Fetch(\"roc-stable\", Recipes.roc_nightly(\"nightly-2026-10-09-258ab27\"))"
expect Headers.stable_tag(stable_declaration) == Ok("nightly-2026-10-09-258ab27")
expect Headers.stable_tag("Programs([\n\tFetch(\n\t\t\"roc-stable\",\n\t\tRecipes.roc_nightly(\"nightly-2026-10-09-258ab27\"),\n\t),\n])") == Ok("nightly-2026-10-09-258ab27")
expect Headers.stable_tag("# `roc-stable` is the release named below\n") == Err(NoStableCompiler)
expect Headers.stable_tag("Fetch(\"roc-stable\", Recipes.roc_nightly(\"\"))") == Err(NoStableCompiler)
expect Headers.stable_tag("${stable_declaration}\n${stable_declaration}") == Err(NoStableCompiler)
expect Headers.stable_tag("# ${stable_declaration}\n") == Err(NoStableCompiler)
expect Headers.stable_tag("# ${stable_declaration}\n${stable_declaration}") == Ok("nightly-2026-10-09-258ab27")
expect Headers.dependency(example, "ansi") == Ok("../package/main.roc")
expect Headers.dependency(example, "pf") == Ok("https://example.com/cli.tar.zst")
expect Headers.dependency(example, "weaver") == Err(MissingDependency("weaver"))
expect Headers.dependency("app [main!] { ansi: \"a\", ansi: \"b\" }\n", "ansi") == Err(DuplicateDependency("ansi"))
