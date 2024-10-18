app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import ansi.ANSI

main =
    [
        "Default color" |> ANSI.color { fg: Default, bg: Default },
        "Ansi 16 colors",
        "Standard Red   fg" |> ANSI.color { fg: Standard Red },
        "Standard Green fg" |> ANSI.color { fg: Standard Green },
        "Standard Blue  fg" |> ANSI.color { fg: Standard Blue },
        "Bright   Red   bg" |> ANSI.color { bg: Bright Red },
        "Bright   Green bg" |> ANSI.color { bg: Bright Green },
        "Bright   Blue  bg" |> ANSI.color { bg: Bright Blue },
        "0" |> ANSI.color { bg: C256 0 },
        "1" |> ANSI.color { bg: C256 1 },
        "2" |> ANSI.color { bg: C256 2 },
        "3" |> ANSI.color { bg: C256 3 },
        "4" |> ANSI.color { bg: C256 4 },
        "5" |> ANSI.color { bg: C256 5 },
        "6" |> ANSI.color { bg: C256 6 },
        "{ fg: Bright Red, bg: Standard Black }" |> ANSI.color { fg: Bright Red, bg: Standard Black },
        "{ fg: Standard Green, bg: Standard Red }" |> ANSI.color { fg: Standard Green, bg: Standard Red },
        "{ fg: Bright Yellow, bg: Standard Green }" |> ANSI.color { fg: Bright Yellow, bg: Standard Green },
        "{ fg: Bright Blue, bg: Bright Yellow }" |> ANSI.color { fg: Bright Blue, bg: Bright Yellow },
        "{ fg: Bright Magenta, bg: Bright Blue }" |> ANSI.color { fg: Bright Magenta, bg: Bright Blue },
        "{ fg: Standard Cyan, bg: Bright Magenta }" |> ANSI.color { fg: Standard Cyan, bg: Bright Magenta },
        "{ fg: Bright White, bg: Standard Cyan }" |> ANSI.color { fg: Bright White, bg: C16 (Standard Cyan) },
        "Ansi 256 colors",
        "{ fg: LightGray, bg: Cyan }" |> ANSI.color { fg: C256 (247), bg: C256 (51) },
        "{ fg: DarkGray, bg: Orange }" |> ANSI.color { fg: C256 (236), bg: C256 (208) },
        "Rgb colors, these aren't supported in all terminals",
        "{ fg: DarkTeal, bg: MintGreen }" |> ANSI.color { fg: Hex (0x008080), bg: Hex (0x98ff98) },
        "{ fg: DarkTeal, bg: MintGreen }" |> ANSI.color { fg: Rgb (0, 128, 128), bg: Rgb (152, 255, 152) },
        "{ fg: CoralPink, bg: RoyalBlue }" |> ANSI.color { fg: Rgb (255, 102, 102), bg: Rgb (65, 105, 225) },
        "{ fg: ElectricPurple, bg: Tangerine }" |> ANSI.color { fg: Rgb (153, 50, 204), bg: Rgb (255, 165, 0) },
        "{ fg: MintGreen, bg: RaspberryRed }" |> ANSI.color { fg: Rgb (152, 255, 152), bg: Rgb (219, 68, 83) },
        "{ fg: SunflowerYellow, bg: DarkTeal }" |> ANSI.color { fg: Rgb (255, 255, 85), bg: Rgb (0, 128, 128) },
        "{ fg: RoyalBlue, bg: Lavender }" |> ANSI.color { fg: Rgb (65, 105, 225), bg: Rgb (230, 230, 250) },
        "{ fg: Lavender, bg: AquaMarine }" |> ANSI.color { fg: Rgb (230, 230, 250), bg: Rgb (127, 255, 212) },
        "{ fg: Tangerine, bg: CoralPink }" |> ANSI.color { fg: Rgb (255, 165, 0), bg: Rgb (255, 102, 102) },
        "{ fg: AquaMarine, bg: SunflowerYellow }" |> ANSI.color { fg: Rgb (127, 255, 212), bg: Rgb (255, 255, 85) },
        "{ fg: RaspberryRed, bg: ElectricPurple }" |> ANSI.color { fg: Rgb (219, 68, 83), bg: Rgb (153, 50, 204) },
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
