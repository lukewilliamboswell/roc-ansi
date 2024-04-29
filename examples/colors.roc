app "example"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
        ansi: "../package/main.roc",
    }
    imports [cli.Task, cli.Stdout, ansi.Core]
    provides [main] to cli

main =
    [
        "Standard Red fg" |> Core.withFg (Standard Red),
        "Standard Green fg" |> Core.withFg (Standard Green),
        "Standard Blue fg" |> Core.withFg (Standard Blue),
        "Standard Red bg" |> Core.withBg (Standard Red),
        "Standard Green bg" |> Core.withBg (Standard Green),
        "Standard Blue bg" |> Core.withBg (Standard Blue),
        "{ fg: Bright Red, bg: Standard Black }" |> Core.withColor { fg: Bright Red, bg: Standard Black },
        "{ fg: Standard Green, bg: Standard Red }" |> Core.withColor { fg: Standard Green, bg: Standard Red },
        "{ fg: Bright Yellow, bg: Standard Green }" |> Core.withColor { fg: Bright Yellow, bg: Standard Green },
        "{ fg: Bright Blue, bg: Bright Yellow }" |> Core.withColor { fg: Bright Blue, bg: Bright Yellow },
        "{ fg: Bright Magenta, bg: Bright Blue }" |> Core.withColor { fg: Bright Magenta, bg: Bright Blue },
        "{ fg: Standard Cyan, bg: Bright Magenta }" |> Core.withColor { fg: Standard Cyan, bg: Bright Magenta },
        "{ fg: Bright White, bg: Standard Cyan }" |> Core.withColor { fg: Bright White, bg: Standard Cyan },
        "{ fg: Default, bg: Default }" |> Core.withColor { fg: Default, bg: Default },
        "{ fg: LightGray, bg: Cyan }" |> Core.withColor { fg: B8 (247), bg: B8 (51) },
        "{ fg: DarkGray, bg: Orange }" |> Core.withColor { fg: B8 (236), bg: B8 (208) },
        # These aren't supported in all terminals
        "{ fg: DarkTeal, bg: MintGreen }" |> Core.withColor { fg: B24 (0, 128, 128), bg: B24 (152, 255, 152) },
        "{ fg: CoralPink, bg: RoyalBlue }" |> Core.withColor { fg: B24 (255, 102, 102), bg: B24 (65, 105, 225) },
        "{ fg: ElectricPurple, bg: Tangerine }" |> Core.withColor { fg: B24 (153, 50, 204), bg: B24 (255, 165, 0) },
        "{ fg: MintGreen, bg: RaspberryRed }" |> Core.withColor { fg: B24 (152, 255, 152), bg: B24 (219, 68, 83) },
        "{ fg: SunflowerYellow, bg: DarkTeal }" |> Core.withColor { fg: B24 (255, 255, 85), bg: B24 (0, 128, 128) },
        "{ fg: RoyalBlue, bg: Lavender }" |> Core.withColor { fg: B24 (65, 105, 225), bg: B24 (230, 230, 250) },
        "{ fg: Lavender, bg: AquaMarine }" |> Core.withColor { fg: B24 (230, 230, 250), bg: B24 (127, 255, 212) },
        "{ fg: Tangerine, bg: CoralPink }" |> Core.withColor { fg: B24 (255, 165, 0), bg: B24 (255, 102, 102) },
        "{ fg: AquaMarine, bg: SunflowerYellow }" |> Core.withColor { fg: B24 (127, 255, 212), bg: B24 (255, 255, 85) },
        "{ fg: RaspberryRed, bg: ElectricPurple }" |> Core.withColor { fg: B24 (219, 68, 83), bg: B24 (153, 50, 204) },
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
