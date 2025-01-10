app [main!] {
    #cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.18.0/0APbwVN1_p1mJ96tXjaoiUCr8NBGamr8G8Ac_DrXR-o.tar.br",
    cli: platform "../../basic-cli/platform/main.roc",
    ansi: "../package/main.roc",
}

import cli.Stdout
import ansi.ANSI

main! = \_ ->
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
