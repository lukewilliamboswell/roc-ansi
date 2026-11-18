app [main!] {
	ansi: "../../package/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.28.1/7brgwR8YUqfeGrkdfF1V4GPPN7DnP7ftqub9KcrTEZtr.tar.zst",
}

import ansi.ANSI
import pf.Path
import pf.Stdout

# Expected clusters come from the official Unicode 17 GraphemeBreakTest file.
# The fixture records its immutable URL, original digest and license.
main! = |_args| {
	fixture : { cases : List(List(Str)) }
	fixture = Json.parse(Path.read_utf8!("tests/unicode/grapheme-breaks.json")?)?
	if fixture.cases.len() != 766 {
		crash "Unicode conformance fixture is incomplete"
	}
	for clusters in fixture.cases {
		text = Str.join_with(clusters, "")
		draw = ANSI.draw_text(text, { r: 2, c: 3, fg: Default, bg: Default, styles: [] })
		var $index = 0
		for cluster in clusters {
			match draw({ row: 0, col: 0 }, { row: 2, col: 3 + $index }) {
				Ok(pixel) if pixel.char == cluster => {}
				_ => crash "grapheme split: ${Str.inspect(clusters)} at ${$index.to_str()}"
			}
			$index = $index + 1
		}
		if draw({ row: 0, col: 0 }, { row: 2, col: 3 + $index }) != Err({}) {
			crash "text extended past its last cluster"
		}
		if draw({ row: 0, col: 0 }, { row: 1, col: 3 }) != Err({}) {
			crash "text appeared on another row"
		}
		if draw({ row: 0, col: 0 }, { row: 2, col: 2 }) != Err({}) {
			crash "text appeared before its starting column"
		}
	}
	Stdout.line!("PASS ${fixture.cases.len().to_str()} Unicode 17 grapheme conformance cases through ANSI.draw_text")
}
