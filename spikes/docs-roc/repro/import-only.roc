app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0-rc2/Gj3zVDr3qrQa6aTh7Z1zgUfe9NeBE6R76T5ho3xrc8af.tar.zst",
	pdf: "https://github.com/lukewilliamboswell/roc-pdf/releases/download/0.1.0-rc3/62BcC7hRi2o5WbafX25XoPwcHzyj39Zsh2SqLjoZKx3p.tar.zst",
}

import cli.Stdout
import pdf.Pdf

main! = |_args| {
	_ = Pdf.paragraph("Hello")
	Stdout.line!("hello")
}
