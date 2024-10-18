app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import ansi.ANSI

main =
    [
        "The ",
        "GREEN" |> ANSI.color { fg: Standard Green },
        " frog, the ",
        "BLUE" |> ANSI.color { fg: Standard Blue },
        " bird, and the ",
        "RED" |> ANSI.color { fg: Standard Red },
        " ant shared a leaf.",
    ]
    |> Str.joinWith ""
    |> Stdout.line
