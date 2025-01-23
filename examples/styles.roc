app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/bi5zubJ-_Hva9vxxPq4kNx4WHX6oFs8OP6Ad0tCYlrY.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import ansi.ANSI

main! = |_|
    [
        "Bold On" |> ANSI.style([Bold(On)]) |> ANSI.style([Default]),
        "Faint On" |> ANSI.style([Faint(On)]) |> ANSI.style([Default]),
        "Italic On" |> ANSI.style([Italic(On)]) |> ANSI.style([Default]),
        "Strikethrough On" |> ANSI.style([Strikethrough(On)]) |> ANSI.style([Default]),
        "Underline On" |> ANSI.style([Underline(On)]) |> ANSI.style([Default]),
        "Invert On" |> ANSI.style([Invert(On)]) |> ANSI.style([Default]),
        "Combination" |> ANSI.style([Bold(On), Italic(On), Strikethrough(On), Underline(On)]),
        "This should have the last style",
        "This shouldn't have any style" |> ANSI.style([Default]),
    ]
    |> Str.join_with("\n")
    |> Stdout.line!
