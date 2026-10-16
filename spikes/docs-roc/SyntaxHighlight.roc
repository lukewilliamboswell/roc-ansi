import parser.RocSyntax

## Pure Roc highlighting: original UTF-8 byte ranges and a caller-selected
## palette. No HTML, PDF, font, platform or layout dependency. Consumers declare
## the parser package in their app header; see README.md for the pinned bundle.
SyntaxHighlight :: [].{
	Category : RocSyntax.HighlightCategory
	Span : { start : U64, end : U64, category : Category }
	Rgb : { red : U8, green : U8, blue : U8 }
	Theme : { text : Rgb, comment : Rgb, name : Rgb, type_name : Rgb, keyword : Rgb, number : Rgb, string : Rgb, symbol : Rgb, invalid : Rgb }
	Foreground : { start : U64, end : U64, color : Rgb }

	## A readable light palette shared by HTML and PDF adapters.
	light : Theme
	light = {
		text: { red: 43, green: 49, blue: 61 },
		comment: { red: 82, green: 101, blue: 115 },
		name: { red: 52, green: 84, blue: 164 },
		type_name: { red: 0, green: 90, blue: 133 },
		keyword: { red: 118, green: 57, blue: 165 },
		number: { red: 156, green: 61, blue: 16 },
		string: { red: 36, green: 99, blue: 51 },
		symbol: { red: 70, green: 83, blue: 105 },
		invalid: { red: 172, green: 38, blue: 52 },
	}

	## Lexer-only: partial snippets are highlighted without requiring a valid
	## file or type checking. EOF is omitted. Adjacent equal categories merge,
	## including string delimiters/contents. Text is never normalized here.
	highlight : Str -> List(Span)
	highlight = |source| {
		lexed = RocSyntax.tokenize_str(source)
		var $cursor = 0
		var $spans = []
		for token in lexed.tokens {
			if token.start != $cursor or token.end < token.start or token.end > lexed.source.len() {
				return plain(source)
			}
			$cursor = token.end
			if token.end > token.start {
				text = Str.from_utf8(lexed.source.sublist({ start: token.start, len: token.end - token.start }))
				if text.is_err() {
					return plain(source)
				}
				span = { start: token.start, end: token.end, category: RocSyntax.highlight_category(token.kind) }
				match $spans.last() {
					Ok(previous) if previous.category == span.category => {
						$spans = $spans.drop_last(1).append({ ..previous, end: span.end })
					}
					_ => {
						$spans = $spans.append(span)
					}
				}
			}
		}
		if $cursor == lexed.source.len() $spans else plain(source)
	}

	## The adapter should slice the original source, never a wrapped version.
	text : Str, Span -> Str
	text = |source, span| Str.from_utf8_lossy(source.to_utf8().sublist({ start: span.start, len: span.end - span.start }))

	color : Theme, Category -> Rgb
	color = |theme, category| match category {
		Trivia => theme.text
		CommentText => theme.comment
		Name => theme.name
		TypeName => theme.type_name
		ReservedWord => theme.keyword
		NumericLiteral => theme.number
		StringText => theme.string
		Symbol => theme.symbol
		InvalidText => theme.invalid
	}

	## Ranges remain in original source coordinates. Trivia inherits the block
	## colour. Consumers convert RGB to their renderer's colour type.
	foregrounds : Theme, List(Span) -> List(Foreground)
	foregrounds = |theme, spans| spans.keep_if(|span| span.category != Trivia).map(|span| { start: span.start, end: span.end, color: color(theme, span.category) })

	name : Category -> Str
	name = |category| match category {
		Trivia => "plain"
		CommentText => "comment"
		Name => "name"
		TypeName => "type"
		ReservedWord => "keyword"
		NumericLiteral => "number"
		StringText => "string"
		Symbol => "symbol"
		InvalidText => "invalid"
	}
}

plain = |source| if source.is_empty() [] else [{ start: 0, end: source.to_utf8().len(), category: Trivia }]

# These properties cover the interchange contract, not lexer grammar details.
expect {
	inputs = ["", "app [main!] {}\n", "# café\r\n\tvalue = \"green\"\n\n", "value = \"unterminated", "value = \"\u(0301)\"\n"]
	inputs.all(
		|source| {
			spans = SyntaxHighlight.highlight(source)
			Str.join_with(spans.map(|span| SyntaxHighlight.text(source, span)), "") == source and spans.all(|span| span.start < span.end)
		},
	)
}

expect {
	spans = SyntaxHighlight.highlight("\"green\"")
	spans == [{ start: 0, end: 7, category: StringText }]
}

expect {
	spans = SyntaxHighlight.highlight("app value = 42 # comment\n")
	spans.any(|span| span.category == ReservedWord) and spans.any(|span| span.category == Name) and spans.any(|span| span.category == NumericLiteral) and spans.any(|span| span.category == CommentText)
}
