app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	ansi: "../package/main.roc",
}

import pf.Stdout
import ansi.ANSI
import ansi.C16
import ansi.Color

main! = |_args| {
	parts = [
		"The ",
		ANSI.color("GREEN", { fg: Color.Standard(C16.Name.Green), bg: Color.Default }),
		" frog, the ",
		ANSI.color("BLUE", { fg: Color.Standard(C16.Name.Blue), bg: Color.Default }),
		" bird, and the ",
		ANSI.color("RED", { fg: Color.Standard(C16.Name.Red), bg: Color.Default }),
		" ant shared a leaf.",
	]

	Stdout.line!(Str.join_with(parts, ""))
	Ok({})
}
