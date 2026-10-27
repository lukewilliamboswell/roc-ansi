app [main!] {
	ansi: "../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst",
}

import pf.Stdout
import ansi.ANSI

# Colour a few words inside a sentence.
#
#     roc examples/animals.roc
#
# `ANSI.color` takes the text and a record with a foreground and a background
# colour. It returns the text wrapped in the escape codes that switch those
# colours on, followed by a reset, so the words around it keep the terminal's
# own colours.
main! = |_args| {
	parts = [
		"The ",
		# `Standard(Green)` is one of the eight standard ANSI colours, which
		# every terminal supports. `Default` leaves the background alone.
		ANSI.color("GREEN", { fg: Standard(Green), bg: Default }),
		" frog, the ",
		ANSI.color("BLUE", { fg: Standard(Blue), bg: Default }),
		" bird, and the ",
		ANSI.color("RED", { fg: Standard(Red), bg: Default }),
		" ant shared a leaf.",
	]

	# The coloured pieces are ordinary strings, so they join like any others.
	Stdout.line!(Str.join_with(parts, ""))?
	Ok({})
}
