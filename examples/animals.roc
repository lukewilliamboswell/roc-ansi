app "example"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.5.0/Cufzl36_SnJ4QbOoEmiJ5dIpUxBvdB3NEySvuH82Wio.tar.br",
        pkg: "https://github.com/lukewilliamboswell/roc-ansi-escapes/releases/download/0.1.1/cPHdNPNh8bjOrlOgfSaGBJDz6VleQwsPdW0LJK6dbGQ.tar.br",
    }
    imports [cli.Stdout, pkg.Color.{ fg }]
    provides [main] to cli

main =
    [
        "The ",
        "GREEN" |> Color.fg Green,
        " frog, the ",
        "BLUE" |> Color.fg Blue,
        " bird, and the ",
        "RED" |> Color.fg Red,
        " ant shared a leaf.",
    ]
    |> Str.joinWith ""
    |> Stdout.line
