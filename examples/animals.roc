app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.12.0/Lb8EgiejTUzbggO2HVVuPJFkwvvsfW6LojkLR20kTVE.tar.br",
    ansi: "../package/main.roc",
}

import cli.Task
import cli.Stdout
import ansi.Core

main =
    [
        "The ",
        "GREEN" |> Core.color { fg: Standard Green },
        " frog, the ",
        "BLUE" |> Core.color { fg: Standard Blue },
        " bird, and the ",
        "RED" |> Core.color { fg: Standard Red },
        " ant shared a leaf.",
    ]
    |> Str.joinWith ""
    |> Stdout.line
