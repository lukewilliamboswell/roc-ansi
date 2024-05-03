app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    ansi: "../package/main.roc",
}

import cli.Task
import cli.Stdout
import ansi.Core

main =
    [
        "The ",
        "GREEN" |> Core.withFg (Standard Green),
        " frog, the ",
        "BLUE" |> Core.withFg (Standard Blue),
        " bird, and the ",
        "RED" |> Core.withFg (Standard Red),
        " ant shared a leaf.",
    ]
    |> Str.joinWith ""
    |> Stdout.line
