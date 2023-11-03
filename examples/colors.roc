app "example"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.5.0/Cufzl36_SnJ4QbOoEmiJ5dIpUxBvdB3NEySvuH82Wio.tar.br",
        pkg: "../package/main.roc",
    }
    imports [
        cli.Stdout,
        pkg.Color,
    ]
    provides [main] to cli

main =
    [
        "Red fg" |> Color.fg Red,
        "Green fg" |> Color.fg Green,
        "Blue fg" |> Color.fg Blue,
        "Red bg" |> Color.bg Red,
        "Green bg" |> Color.bg Green,
        "Blue bg" |> Color.bg Blue,
        "{ fg: BrightRed, bg: Black}" |> Color.with { fg: BrightRed, bg: Black},
        "{ fg: Green, bg: Red}" |> Color.with { fg: Green, bg: Red},
        "{ fg: BrightYellow, bg: Green}" |> Color.with { fg: BrightYellow, bg: Green},
        "{ fg: BrightBlue, bg: BrightYellow}" |> Color.with { fg: BrightBlue, bg: BrightYellow},
        "{ fg: BrightMagenta, bg: BrightBlue}" |> Color.with { fg: BrightMagenta, bg: BrightBlue},
        "{ fg: Cyan, bg: BrightMagenta}" |> Color.with { fg: Cyan, bg: BrightMagenta},
        "{ fg: BrightWhite, bg: Cyan}" |> Color.with { fg: BrightWhite, bg: Cyan},
        "{ fg: Default, bg: Default}" |> Color.with { fg: Default, bg: Default},
    ]
    |> Str.joinWith "\n"
    |> Stdout.line 
