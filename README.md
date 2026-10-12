# roc-ansi

Colour and style what a [Roc](https://www.roc-lang.org) program prints, move
the cursor, read key presses and draw simple tables, without writing ANSI
escape codes by hand. It is a pure Roc package and works with any platform
that can write to a terminal.

**[Read the manual](https://lukewilliamboswell.github.io/roc-ansi/)** ·
[Latest release](https://github.com/lukewilliamboswell/roc-ansi/releases/latest)

```roc
app [main!] {
	ansi: "<the bundle URL of the latest release>",
}

import ansi.ANSI

main! = |_args| {
	echo!(ANSI.color("hello", { fg: Standard(Green), bg: Default }))
	Ok({})
}
```

[Get started](https://lukewilliamboswell.github.io/roc-ansi/getting-started.html)
has this program with the current URL filled in.

## Examples

| | |
| --- | --- |
| [`animals.roc`](examples/animals.roc)<br>![a sentence with three coloured words](docs/images/animals.png) | [`styles.roc`](examples/styles.roc)<br>![bold, faint, italic, strikethrough, underlined and inverted text](docs/images/styles.png) |
| [`colors.roc`](examples/colors.roc)<br>![text in the 16 named colours, 256-colour and RGB](docs/images/colors.png) | [`menu.roc`](examples/menu.roc)<br>![a menu with its first entry highlighted](docs/images/menu.png) |
| [`piece-table.roc`](examples/piece-table.roc)<br>![a document after an insertion and a deletion](docs/images/piece-table.png) | |

The examples in this repository follow `main`. To start a project, download
the examples attached to a
[release](https://github.com/lukewilliamboswell/roc-ansi/releases/latest),
which depend on that release.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). roc-ansi is open source under the
[Universal Permissive License 1.0](LICENSE).
