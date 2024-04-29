app "example"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
        ansi: "../package/main.roc",
    }
    imports [cli.Task, cli.Stdout, ansi.Core]
    provides [main] to cli

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
