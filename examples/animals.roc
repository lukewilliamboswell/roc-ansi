app "example"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        ansi: "../package/main.roc",
    }
    imports [cli.Stdout, ansi.Core]
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
