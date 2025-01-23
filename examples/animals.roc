app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/bi5zubJ-_Hva9vxxPq4kNx4WHX6oFs8OP6Ad0tCYlrY.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import ansi.ANSI

main! = |_|
    [
        "The ",
        "GREEN" |> ANSI.color({ fg: Standard(Green) }),
        " frog, the ",
        "BLUE" |> ANSI.color({ fg: Standard(Blue) }),
        " bird, and the ",
        "RED" |> ANSI.color({ fg: Standard(Red) }),
        " ant shared a leaf.",
    ]
    |> Str.join_with("")
    |> Stdout.line!
