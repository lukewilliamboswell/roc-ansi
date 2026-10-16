app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0-rc2/Gj3zVDr3qrQa6aTh7Z1zgUfe9NeBE6R76T5ho3xrc8af.tar.zst",
	parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.1.0-rc.1/6dvNG3Q2mx53i4YPJN2ZGK98WdXnBMMuceAmDsCq7BEd.tar.zst",
}

import cli.OsStr
import cli.Stdout
import SyntaxHighlight

# Independent usage example: no PDF, fonts or manual assets are imported.
main! = |args| {
	source = Str.join_with(args.map(OsStr.display), " ")
	for span in SyntaxHighlight.highlight(source) {
		Stdout.line!("${span.start.to_str()}..${span.end.to_str()} ${SyntaxHighlight.name(span.category)} ${Str.inspect(SyntaxHighlight.text(source, span))}")?
	}
	Ok({})
}
