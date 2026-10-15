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
import pdf.Color
import pdf.Theme
import pdf.Document
import pdf.Font
import pdf.Image
import pdf.Layout
import pdf.Pdf
import pdf.Scene
import "fonts/NotoSans-Regular.ttf" as regular_bytes : List(U8)
import "fonts/NotoSans-Italic.ttf" as italic_bytes : List(U8)
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
	fonts = register_fonts()?
	options = renderer_options(fonts)
	body = pdf_blocks(blocks, options, False)?
	contents = if body.is_empty() front_matter(blocks) else front_matter(blocks).append(Pdf.page_break).concat(body)
	document = Pdf.document({ contents, language: "en-AU", title: "The roc-ansi manual", outline: outline(blocks), page_templates: Templates(page_templates()) })
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
	italic = add(bold.registry, italic_bytes)?
	mono = add(italic.registry, mono_bytes)?
	Ok({ regular: regular.face, bold: bold.face, italic: italic.face, mono: mono.face, registry: mono.registry })
}

rgb = |red, green, blue| Color.srgb8({ red, green, blue })

renderer_options = |fonts| {
	options : Pdf.Options
	options = {
		fonts: Registered(fonts.registry),
		page_size: A4,
		theme: {
			face: fonts.regular,
			body: { color: rgb(43, 49, 61), size: 10, leading: 14 },
			paragraph_spacing: 0,
			page_margin: { top: 40, right: 52, bottom: 38, left: 52 },
			title: { face: Face(fonts.bold), color: rgb(23, 53, 90), size: 34, leading: 42 },
			headings: {
				all: { face: Face(fonts.bold), color: rgb(23, 53, 90), size: 13, leading: 18 },
				h1: Own({ face: Face(fonts.bold), color: rgb(23, 53, 90), size: 24, leading: 31 }),
				h2: Own({ face: Face(fonts.bold), color: rgb(23, 53, 90), size: 18, leading: 25 }),
			},
			inline: { code: { font: Face(fonts.mono), scale: Percent(90), color: Themed(rgb(39, 62, 94)) }, strong: { font: Face(fonts.bold) }, emphasis: { font: Face(fonts.italic) } },
			link: { color: Themed(rgb(22, 91, 160)), underline: Underline({ offset: 1, thickness: 0.4 }) },
			table: {
				cell_padding: 7,
				row_gap: 8,
				header_fill: Fill(rgb(229, 237, 247)),
				header_color: Themed(rgb(23, 53, 90)),
				body_fills: { odd: Fill(rgb(247, 249, 252)) },
				rule: Rule({ color: rgb(173, 192, 215), width: 0.6 }),
				body_rule: Rule({ color: rgb(225, 231, 238), width: 0.3 }),
			},
		},
	}
	options
}

page_templates = || {
	rule = Scene.Drawing.empty.rectangle({ origin: { x: 0, y: 0 }, size: { width: 491, height: 0.5 } }, rgb(202, 213, 228))
	header = Pdf.region({ height: 22, slot_inset: 6, backdrop: Backdrop(rule), start: [Pdf.furniture_text([Pdf.text("roc-ansi / Manual")])], end: [Pdf.furniture_text([Pdf.text("0.13.2")])] })
	footer = Pdf.region({ height: 22, slot_inset: 6, backdrop: Backdrop(rule), start: [Pdf.furniture_text([Pdf.text("Roc documentation experiment")])], end: [Pdf.furniture_text([Pdf.page_number(Decimal), Pdf.text(" / "), Pdf.total_pages(Decimal)])] })
	{ first: Pdf.first_page_template({ footer, gap: 14 }), continuation: Pdf.page_template({ header, footer, gap: 14 }) }
}

front_matter = |blocks| {
	var $title = "The roc-ansi manual"
	for block in blocks {
		match block {
			Heading({ level: One, content }) => {
				$title = plain(content)
			}
			_ => {}
		}
	}
	var $contents = [
		Pdf.paragraph("ROC PACKAGE MANUAL · 0.13.2"),
		Pdf.spacer(30),
		Pdf.title($title),
		Pdf.destination_paragraph(slug($title), "Colour, style and interaction for terminal applications."),
		Pdf.spacer(20),
		Pdf.decoration({ drawing: Scene.Drawing.empty.rectangle({ origin: { x: 0, y: 0 }, size: { width: 70, height: 4 } }, rgb(22, 91, 160)), below: 22 }),
		Pdf.paragraph("A pure Roc package for expressive command-line interfaces."),
		Pdf.spacer(30),
		Pdf.heading(1, "Contents"),
	]
	for block in blocks {
		match block {
			Heading({ level, content }) if level_number(level) == 2 => {
				$contents = $contents.append(Pdf.rich_paragraph([Pdf.inline_internal_link([Pdf.strong([Pdf.text(plain(content))])], slug(plain(content)))])).append(Pdf.spacer(7))
			}
			Heading({ level: Three, content }) => {
				$contents = $contents.append(Pdf.rich_paragraph([Pdf.text("    "), Pdf.inline_internal_link([Pdf.text(plain(content))], slug(plain(content)))])).append(Pdf.spacer(7))
			}
			_ => {}
		}
	}
	$contents.append(Pdf.spacer(25)).append(Pdf.paragraph("Experimental edition · rendered entirely with Roc, roc-parser and roc-pdf."))
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

pdf_blocks : List(Markdown), Pdf.Options, Bool -> Try(List(Document.Block), _)
pdf_blocks = |blocks, options, in_list| {
	var $result = []
	for entry in blocks.map_with_index(|block, index| { block, index }) {
		block = entry.block
		match block {
			Heading({ level, content }) => {
				if level_number(level) > 1 {
					$result = $result.append(Pdf.spacer(if level_number(level) == 2 14 else 7))
				}
				if level_number(level) != 1 {
					$result = $result.append(Pdf.destination_heading(slug(plain(content)), level_number(level), plain(content)))
				}
			}
			Paragraph([Image({ alt, target })]) => {
				if target.href != "animals.png" {
					return Err(UnsupportedImage(target.href))
				}
				image = Image.Source.rgb8({ dimensions: { width: 658, height: 102 }, pixels: animal_pixels, row_stride: 1974, alpha: NoAlpha })
				drawing = Scene.Drawing.empty.image(image, { origin: { x: 0, y: 0 }, size: { width: 491, height: 76.112 } })
				$result = $result.append(Pdf.figure({ drawing, alt: plain(alt), caption: Pdf.caption(plain(alt)) })).append(Pdf.spacer(7))
			}
			Paragraph(inlines) => {
				paragraph = Pdf.rich_paragraph(pdf_inlines(inlines)?)
				followed_by_image = match blocks.get(entry.index + 1) {
					Ok(Paragraph([Image(_)])) => True
					_ => False
				}
				$result = $result.append(if followed_by_image Pdf.keep_with_next(Required, paragraph) else paragraph)
				if !in_list and !followed_by_image {
					$result = $result.append(Pdf.spacer(7))
				}
			}
			Code({ pre, .. }) => {
				$result = $result.append(code_panel(pre, options)?)
				$result = $result.append(Pdf.spacer(6))
			}
			Table({ header, rows, align }) => {
				var $headers = []
				for cell in header {
					$headers = $headers.append(Pdf.header_cell(Column, [Pdf.strong(pdf_inlines(cell)?)]))
				}
				var $rows = []
				for row in rows {
					var $cells = []
					for cell in row {
						$cells = $cells.append(Pdf.cell(pdf_inlines(cell)?))
					}
					$rows = $rows.append(Pdf.row($cells))
				}
				table = Pdf.table({
					caption: Pdf.no_caption,
					columns: align.map_with_index(
						|alignment, index| {
							width: if index == align.len() - 1 Share(1) else Content,
							align: match alignment {
								Right => End
								Center => Center
								_ => Start
							},
						},
					),
					header_rows: [Pdf.row($headers)],
					body_rows: $rows,
				})
				$result = $result.append(if rows.len() <= 8 Pdf.keep_together([table]) else table).append(Pdf.spacer(7))
			}
			ListBlock({ kind, items, .. }) => {
				var $items = []
				for item in items {
					if item.task != NoTask {
						return Err(UnsupportedMarkdown("task list"))
					}
					$items = $items.append(Pdf.list_item(pdf_blocks(item.blocks, options, True)?))
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

# Each visual code line is a paragraph: this avoids the rc3 rich-inline
# boundary rejection for repeated ASCII and consecutive blank lines.
# Zero global paragraph spacing keeps source lines on a consistent grid;
# ordinary Markdown paragraphs receive an explicit spacer above.
code_panel : Str, Pdf.Options -> Try(Document.Block, _)
code_panel = |source, options| {
	var $contents = []
	for line in Str.split_on(source.drop_suffix("\n"), "\n") {
		if Str.to_utf8(line).any(|byte| byte > 127) {
			return Err(UnsupportedMarkdown("non-ASCII code needs a Unicode-aware wrapping policy"))
		}
		for visual_line in wrap_code(Str.join_with(Str.split_on(line, "\t"), "    ")) {
			$contents = $contents.append(Pdf.rich_paragraph([Pdf.code(if visual_line.is_empty() " " else visual_line)]))
		}
	}
	contents = $contents
	height = Pdf.measure_custom_content(options, { contents, language: "en-AU", width: 471 }).map_err(|error| PdfRejected(error))?
	size = { width: Layout.Unit.points(491), height: Layout.Unit.from_raw(height.raw() + 20000) }
	panel = Scene.Drawing.empty.rectangle({ origin: { x: 0, y: 0 }, size }, rgb(244, 246, 249))
	Ok(Pdf.custom_block({ contents, inset: 10, name: "Source code", panel, size }))
}

# Prefer a source separator near the end of the line, keeping that separator.
# Continuation indentation is visual only; HTML retains every original byte.
wrap_code = |line| {
	var $indent = 0
	for byte in Str.to_utf8(line).take_first(12) {
		if byte == ' ' {
			$indent = $indent + 1
		} else {
			break
		}
	}
	continuation = Str.repeat(" ", $indent + 4)
	var $prefix = ""
	var $remaining = Str.to_utf8(line)
	var $lines = []
	while $remaining.len() + Str.to_utf8($prefix).len() > 86 {
		limit = 86 - Str.to_utf8($prefix).len()
		var $split = limit
		for candidate in $remaining.take_first(limit).map_with_index(|byte, index| { byte, index }) {
			if candidate.index >= limit // 2 and (candidate.byte == '/' or candidate.byte == ' ' or candidate.byte == ',') {
				$split = candidate.index + 1
			}
		}
		$lines = $lines.append("${$prefix}${Str.from_utf8_lossy($remaining.take_first($split))}")
		$remaining = $remaining.drop_first($split)
		$prefix = continuation
	}
	$lines.append("${$prefix}${Str.from_utf8_lossy($remaining)}")
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
