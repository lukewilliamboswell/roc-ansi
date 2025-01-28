app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
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
