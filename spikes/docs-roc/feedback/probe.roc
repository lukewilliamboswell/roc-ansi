app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0-rc2/Gj3zVDr3qrQa6aTh7Z1zgUfe9NeBE6R76T5ho3xrc8af.tar.zst",
	pdf: "https://github.com/lukewilliamboswell/roc-pdf/releases/download/0.1.0-rc3/62BcC7hRi2o5WbafX25XoPwcHzyj39Zsh2SqLjoZKx3p.tar.zst",
}

import cli.OsStr
import cli.Stdout
import pdf.Color
import pdf.Layout
import pdf.Pdf
import pdf.Scene

main! = |args| {
	mode = match args.map(OsStr.display) {
		[value] => value
		_ => return Err(Usage("probe.roc -- body-page-field | footer-page-field | tall-panel | default-empty-panel | ascii-break | blank-breaks"))
	}
	document = match mode {
		"body-page-field" => Pdf.document({
			contents: [Pdf.rich_paragraph([Pdf.text("This body paragraph is on page "), Pdf.page_number(Decimal)])],
			language: "en",
			title: "Body page field",
		})
		"footer-page-field" => {
			footer = Pdf.region({ height: 18, end: [Pdf.furniture_text([Pdf.text("Page "), Pdf.page_number(Decimal), Pdf.text(" of "), Pdf.total_pages(Decimal)])] })
			Pdf.document({
				contents: [Pdf.paragraph("First page"), Pdf.page_break, Pdf.paragraph("Second page")],
				language: "en",
				page_templates: Templates({ first: Pdf.first_page_template({ footer, gap: 12 }), continuation: Pdf.page_template({ footer, gap: 12 }) }),
				title: "Footer page field control",
			})
		}
		"small-furniture-label" => {
			drawing = Scene.Drawing.empty.text({ origin: { x: 0, y: 3 }, size: 8, text: "Quiet running header" })
			header = Pdf.region({ height: 18, start: [Pdf.furniture_image(drawing)] })
			Pdf.document({
				contents: [Pdf.paragraph("Body text")],
				language: "en",
				page_templates: Templates({ first: Pdf.first_page_template({ header, gap: 12 }), continuation: Pdf.page_template({ header, gap: 12 }) }),
				title: "Explicitly sized furniture drawing label",
			})
		}
		"tall-panel" => Pdf.document({
			contents: [
				Pdf.custom_block({
					contents: [Pdf.paragraph("A valid custom block that is taller than one page's body.")],
					inset: 8,
					name: "Long code panel",
					panel: Scene.Drawing.empty.rectangle(Layout.rect(0, 0, 400, 800), Color.srgb8({ red: 240, green: 240, blue: 240 })),
					size: { height: 800, width: 400 },
				}),
			],
			language: "en",
			title: "Tall custom panel",
		})
		"default-empty-panel" => Pdf.document({
			contents: [
				Pdf.custom_block({
					contents: [Pdf.paragraph("Text without a decorative panel.")],
					inset: 8,
					name: "No decorative panel supplied",
					size: { height: 80, width: 400 },
				}),
			],
			language: "en",
			title: "Default custom block panel",
		})
		"ascii-break" => Pdf.document({
			contents: [Pdf.rich_paragraph([Pdf.code("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"), Pdf.line_break, Pdf.code("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")])],
			language: "en",
			title: "ASCII code line break",
		})
		"short-ascii-break" => Pdf.document({
			contents: [Pdf.rich_paragraph([Pdf.code("xxxx"), Pdf.line_break, Pdf.code("xxxx")])],
			language: "en",
			title: "Short ASCII code line break",
		})
		"blank-breaks" => Pdf.document({
			contents: [Pdf.rich_paragraph([Pdf.code("first"), Pdf.line_break, Pdf.code(" "), Pdf.line_break, Pdf.code(" "), Pdf.line_break, Pdf.code("last")])],
			language: "en",
			title: "Consecutive blank code lines",
		})
		_ => return Err(UnknownCase(mode))
	}
	match Pdf.to_bytes(document) {
		Ok(bytes) => Stdout.line!("${mode}: accepted (${bytes.len().to_str()} bytes)")
		Err(problem) => Stdout.line!("${mode}: ${Str.inspect(problem)}")
	}
}
