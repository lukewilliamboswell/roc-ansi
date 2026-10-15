app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0-rc2/Gj3zVDr3qrQa6aTh7Z1zgUfe9NeBE6R76T5ho3xrc8af.tar.zst",
	parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW.tar.zst",
	pdf: "https://github.com/lukewilliamboswell/roc-pdf/releases/download/0.1.0-rc3/62BcC7hRi2o5WbafX25XoPwcHzyj39Zsh2SqLjoZKx3p.tar.zst",
}

import cli.Monotonic
import cli.OsStr
import cli.Path
import cli.Stdout
import parser.Markdown
import pdf.Document
import pdf.Font
import pdf.Image
import pdf.Layout
import pdf.Pdf
import pdf.Scene
import "fonts/NotoSans-Regular.ttf" as regular_bytes : List(U8)
import "fonts/NotoSans-Bold.ttf" as bold_bytes : List(U8)
import "fonts/SourceCodePro-Regular.ttf" as mono_bytes : List(U8)
import "assets/animals.rgb" as animal_pixels : List(U8)
import "../../docs/images/animals.png" as animal_png : List(U8)

main! = |args| {
	(input, output) = match args.map(OsStr.display) {
		[] => ("spikes/docs-roc/chapter.md", ".roc-ansi-tmp/docs-roc")
		[source, destination] => (source, destination)
		_ => return Err(Usage("docs-roc [input.md output-directory]"))
	}
	started = Monotonic.now!()
	blocks = Markdown.parse_str(Path.read_utf8!(Path.utf8(input))?)
	parsed = Monotonic.now!()
	html = html_document(blocks)?
	html_done = Monotonic.now!()
	contents = pdf_blocks(blocks)?
	fonts = register_fonts()?
	options : Pdf.Options
	options = {
		fonts: Registered(fonts.registry),
		theme: {
			face: fonts.regular,
			body: { size: 10, leading: 14 },
			paragraph_spacing: 4,
			page_margin: { top: 42, right: 42, bottom: 42, left: 42 },
			headings: { all: { face: Face(fonts.bold), size: 16, leading: 22 } },
			inline: { code: { font: Face(fonts.mono), scale: Percent(80) }, strong: { font: Face(fonts.bold) } },
		},
	}
	document = Pdf.document({ contents, language: "en-AU", title: "The roc-ansi manual: Roc rendering spike", outline: outline(blocks) })
	lowered = Monotonic.now!()
	prepared = Pdf.prepare_with_report(document, options).map_err(|error| PdfRejected(error))?
	planned = Monotonic.now!()
	bytes = Pdf.to_bytes_prepared(prepared.prepared).map_err(|error| PdfRejected(error))?
	emitted = Monotonic.now!()
	directory = Path.utf8(output)
	Path.create_all!(directory)?
	Path.write_utf8!(Path.join(directory, "index.html"), html)?
	Path.write_bytes!(Path.join(directory, "manual.pdf"), bytes)?
	Path.write_bytes!(Path.join(directory, "animals.png"), animal_png)?
	Stdout.line!("parse=${ms(started, parsed)}ms html=${ms(parsed, html_done)}ms lower_and_fonts=${ms(html_done, lowered)}ms prepare=${ms(lowered, planned)}ms emit=${ms(planned, emitted)}ms total=${ms(started, emitted)}ms pages=${prepared.report.facts.pages.len().to_str()} pdf_bytes=${bytes.len().to_str()}")?
	Stdout.line!("Wrote ${output}/index.html and ${output}/manual.pdf")
}

ms = |before, after| after.since(before).to_millis().to_str()

register_fonts = || {
	latin : List(Font.Script)
	latin = ["Latn"]
	add = |registry, bytes| registry.register(bytes, { provision: BuiltIn, scripts: latin }, Font.ValidationLimits.default).map_err(|error| FontRejected(error))
	regular = add(Font.Registry.empty, regular_bytes)?
	bold = add(regular.registry, bold_bytes)?
	mono = add(bold.registry, mono_bytes)?
	Ok({ regular: regular.face, bold: bold.face, mono: mono.face, registry: mono.registry })
}

plain : List(Markdown.Inline) -> Str
plain = |inlines| Str.join_with(
	inlines.map(
		|inline| match inline {
			Text(text) | InlineCode(text) => text
			Strong(children) | Emphasis(children) | Strikethrough(children) => plain(children)
			Link({ label, .. }) => plain(label)
			Image({ alt, .. }) => plain(alt)
			HardBreak => " "
			HtmlInline(text) => text
		},
	),
	"",
)

slug : Str -> Str
slug = |text| {
	var $bytes = []
	for byte in Str.to_utf8(text) {
		if byte >= 'A' and byte <= 'Z' {
			$bytes = $bytes.append(byte + 32)
		} else if (byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') {
			$bytes = $bytes.append(byte)
		} else if byte == ' ' or byte == '-' {
			$bytes = $bytes.append('-')
		}
	}
	Str.from_utf8_lossy($bytes)
}

outline : List(Markdown) -> List(Document.OutlineEntry)
outline = |blocks| blocks.keep_oks(
	|block| match block {
		Heading({ level, content }) => Ok({ depth: level_number(level).to_u64() - 1, destination: slug(plain(content)), open: True, title: plain(content) })
		_ => Err(NotHeading)
	},
)

level_number : Markdown.Level -> U8
level_number = |level| match level {
	One => 1
	Two => 2
	Three => 3
	Four => 4
	Five => 5
	Six => 6
}

pdf_blocks : List(Markdown) -> Try(List(Document.Block), _)
pdf_blocks = |blocks| {
	var $result = []
	for block in blocks {
		match block {
			Heading({ level, content }) => {
				$result = $result.append(Pdf.destination_heading(slug(plain(content)), level_number(level), plain(content)))
			}
			Paragraph([Image({ alt, target })]) => {
				if target.href != "animals.png" {
					return Err(UnsupportedImage(target.href))
				}
				image = Image.Source.rgb8({ dimensions: { width: 658, height: 102 }, pixels: animal_pixels, row_stride: 1974, alpha: NoAlpha })
				drawing = Scene.Drawing.empty.image(image, { origin: { x: 0, y: 0 }, size: { width: 493.5, height: 76.5 } })
				$result = $result.append(Pdf.figure({ drawing, alt: plain(alt), caption: Pdf.caption(plain(alt)) }))
			}
			Paragraph(inlines) => {
				$result = $result.append(Pdf.rich_paragraph(pdf_inlines(inlines)?))
			}
			Code({ pre, .. }) => {
				for line in Str.split_on(pre.drop_suffix("\n"), "\n") {
					if Str.to_utf8(line).any(|byte| byte > 127) {
						return Err(UnsupportedMarkdown("non-ASCII code needs a Unicode-aware wrapping policy"))
					}
					if line == "" {
						$result = $result.append(Pdf.spacer(5))
					} else {
						$result = $result.append(Pdf.rich_paragraph(code_line(Str.join_with(Str.split_on(line, "\t"), "    "))))
					}
				}
			}
			Table({ header, rows, align }) => {
				var $headers = []
				for cell in header {
					$headers = $headers.append(Pdf.header_cell(Column, pdf_inlines(cell)?))
				}
				var $rows = []
				for row in rows {
					var $cells = []
					for cell in row {
						$cells = $cells.append(Pdf.cell(pdf_inlines(cell)?))
					}
					$rows = $rows.append(Pdf.row($cells))
				}
				$result = $result.append(
					Pdf.table({
						caption: Pdf.no_caption,
						columns: align.map(
							|alignment| {
								width: Share(1),
								align: match alignment {
									Right => End
									Center => Center
									_ => Start
								},
							},
						),
						header_rows: [Pdf.row($headers)],
						body_rows: $rows,
					}),
				)
			}
			ListBlock({ kind, items, .. }) => {
				var $items = []
				for item in items {
					if item.task != NoTask {
						return Err(UnsupportedMarkdown("task list"))
					}
					$items = $items.append(Pdf.list_item(pdf_blocks(item.blocks)?))
				}
				$result = $result.append(
					match kind {
						Unordered => Pdf.bullet_list($items)
						Ordered({ start }) => Pdf.numbered_list(
							{ start: start },
							$items,
						)
					},
				)
			}
			_ => return Err(UnsupportedMarkdown("block: ${Str.inspect(block)}"))
		}
	}
	Ok($result)
}

# PDF-only visual wrapping. HTML keeps the exact source; this deliberately
# exposes the lack of a preformatted code-block API in the PDF facade.
code_line : Str -> List(Pdf.Inline)
code_line = |line| {
	var $result = []
	var $remaining = Str.to_utf8(line)
	while $remaining.len() > 90 {
		$result = $result.append(Pdf.code(Str.from_utf8_lossy($remaining.take_first(90))))
		$result = $result.append(Pdf.line_break)
		$remaining = $remaining.drop_first(90)
	}
	$result.append(Pdf.code(Str.from_utf8_lossy($remaining)))
}

pdf_inlines : List(Markdown.Inline) -> Try(List(Pdf.Inline), _)
pdf_inlines = |inlines| {
	var $result = []
	for inline in inlines {
		value = match inline {
			Text(text) => Pdf.text(Str.join_with(Str.split_on(text, "\n"), " "))
			InlineCode(text) => Pdf.code(text)
			Strong(children) => Pdf.strong(pdf_inlines(children)?)
			Emphasis(children) => Pdf.emphasis(pdf_inlines(children)?)
			Link({ label, target }) => if target.href.starts_with("#") Pdf.inline_internal_link(pdf_inlines(label)?, target.href.drop_prefix("#")) else Pdf.inline_link(pdf_inlines(label)?, target.href)
			HardBreak => Pdf.line_break
			_ => return Err(UnsupportedMarkdown("inline: ${Str.inspect(inline)}"))
		}
		$result = $result.append(value)
	}
	Ok($result)
}

escape : Str -> Str
escape = |text| {
	amp = Str.join_with(Str.split_on(text, "&"), "&amp;")
	lt = Str.join_with(Str.split_on(amp, "<"), "&lt;")
	gt = Str.join_with(Str.split_on(lt, ">"), "&gt;")
	Str.join_with(Str.split_on(gt, "\""), "&quot;")
}

html_inlines : List(Markdown.Inline) -> Try(Str, _)
html_inlines = |inlines| {
	var $result = ""
	for inline in inlines {
		part = match inline {
			Text(text) => escape(text)
			InlineCode(text) => "<code>${escape(text)}</code>"
			Strong(children) => "<strong>${html_inlines(children)?}</strong>"
			Emphasis(children) => "<em>${html_inlines(children)?}</em>"
			Link({ label, target }) => {
				if !target.href.starts_with("https://") and !target.href.starts_with("#") {
					return Err(UnsupportedLink(target.href))
				}
				"<a href=\"${escape(target.href)}\">${html_inlines(label)?}</a>"
			}
			Image({ alt, target }) => {
				if target.href != "animals.png" {
					return Err(UnsupportedImage(target.href))
				}
				"<img src=\"animals.png\" alt=\"${escape(plain(alt))}\">"
			}
			HardBreak => "<br>"
			_ => return Err(UnsupportedMarkdown("inline: ${Str.inspect(inline)}"))
		}
		$result = "${$result}${part}"
	}
	Ok($result)
}

html_blocks : List(Markdown) -> Try(Str, _)
html_blocks = |blocks| {
	var $result = ""
	for block in blocks {
		part = match block {
			Heading({ level, content }) => {
				n = level_number(level).to_str()
				"<h${n} id=\"${slug(plain(content))}\">${html_inlines(content)?}</h${n}>"
			}
			Paragraph(content) => "<p>${html_inlines(content)?}</p>"
			Code({ info, pre }) => "<pre><code class=\"language-${escape(info)}\">${escape(pre)}</code></pre>"
			Table({ header, rows, .. }) => {
				var $head = ""
				for cell in header {
					$head = "${$head}<th>${html_inlines(cell)?}</th>"
				}
				var $body = ""
				for row in rows {
					var $cells = ""
					for cell in row {
						$cells = "${$cells}<td>${html_inlines(cell)?}</td>"
					}
					$body = "${$body}<tr>${$cells}</tr>"
				}
				"<table><thead><tr>${$head}</tr></thead><tbody>${$body}</tbody></table>"
			}
			ListBlock({ kind, items, .. }) => {
				tag = match kind {
					Unordered => "ul"
					Ordered(_) => "ol"
				}
				start = match kind {
					Ordered({ start: value }) => " start=\"${value.to_str()}\""
					_ => ""
				}
				var $items = ""
				for item in items {
					if item.task != NoTask {
						return Err(UnsupportedMarkdown("task list"))
					}
					$items = "${$items}<li>${html_blocks(item.blocks)?}</li>"
				}
				"<${tag}${start}>${$items}</${tag}>"
			}
			_ => return Err(UnsupportedMarkdown("block: ${Str.inspect(block)}"))
		}
		$result = "${$result}${part}\n"
	}
	Ok($result)
}

html_document = |blocks| {
	content = html_blocks(blocks)?
	navigation = Str.join_with(outline(blocks).map(|entry| "<li><a href=\"#${entry.destination}\">${escape(entry.title)}</a></li>"), "")
	Ok("<!doctype html><html lang=\"en-AU\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>The roc-ansi manual: Roc rendering spike</title><style>body{font:17px/1.65 system-ui,sans-serif;color:#203047;max-width:900px;margin:3rem auto;padding:0 1.5rem}a{color:#125bb3}h1,h2,h3{line-height:1.2;scroll-margin-top:2rem}h2{margin-top:3rem;border-bottom:1px solid #d6e0eb;padding-bottom:.5rem}nav{background:#edf3fa;padding:1rem 1.5rem;border-radius:8px}nav ul{columns:2}code{font-family:ui-monospace,monospace;background:#edf3fa;padding:.1rem .25rem}pre{background:#edf3fa;padding:1rem;overflow:auto;border-radius:8px;tab-size:4}pre code{padding:0}table{border-collapse:collapse;width:100%;font-size:.92em}td,th{border:1px solid #d6e0eb;padding:.6rem;text-align:left}th{background:#edf3fa}img{max-width:100%;height:auto}footer{border-top:1px solid #d6e0eb;margin-top:3rem;padding-top:1rem}</style></head><body><p>Experimental Roc documentation renderer · <a href=\"manual.pdf\">Download PDF</a></p><nav aria-label=\"Contents\"><ul>${navigation}</ul></nav><main>${content}</main><footer>Parsed once with roc-parser; rendered directly to HTML and PDF in Roc.</footer></body></html>")
}

expect escape("<&\"") == "&lt;&amp;&quot;"
expect slug("Run the checks") == "run-the-checks"
