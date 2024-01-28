app "example"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        ansi: "../package/main.roc",
    }
    imports [cli.Stdout, ansi.Core]
    provides [main] to cli

main =
    [
        "Red fg" |> Core.withFg Red,
        "Green fg" |> Core.withFg Green,
        "Blue fg" |> Core.withFg Blue,
        "Red bg" |> Core.withBg Red,
        "Green bg" |> Core.withBg Green,
        "Blue bg" |> Core.withBg Blue,
        "{ fg: BrightRed, bg: Black}" |> Core.withColor { fg: BrightRed, bg: Black },
        "{ fg: Green, bg: Red}" |> Core.withColor { fg: Green, bg: Red },
        "{ fg: BrightYellow, bg: Green}" |> Core.withColor { fg: BrightYellow, bg: Green },
        "{ fg: BrightBlue, bg: BrightYellow}" |> Core.withColor { fg: BrightBlue, bg: BrightYellow },
        "{ fg: BrightMagenta, bg: BrightBlue}" |> Core.withColor { fg: BrightMagenta, bg: BrightBlue },
        "{ fg: Cyan, bg: BrightMagenta}" |> Core.withColor { fg: Cyan, bg: BrightMagenta },
        "{ fg: BrightWhite, bg: Cyan}" |> Core.withColor { fg: BrightWhite, bg: Cyan },
        "{ fg: Default, bg: Default}" |> Core.withColor { fg: Default, bg: Default },
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
