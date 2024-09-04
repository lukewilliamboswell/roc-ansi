app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import ansi.Core

main =
    [
        "Default color" |> Core.color { fg: Default, bg: Default },
        "Ansi 16 colors",
        "Standard Red   fg" |> Core.color { fg: Standard Red },
        "Standard Green fg" |> Core.color { fg: Standard Green },
        "Standard Blue  fg" |> Core.color { fg: Standard Blue },
        "Bright   Red   bg" |> Core.color { bg: Bright Red },
        "Bright   Green bg" |> Core.color { bg: Bright Green },
        "Bright   Blue  bg" |> Core.color { bg: Bright Blue },
        "0" |> Core.color { bg: C256 0 },
        "1" |> Core.color { bg: C256 1 },
        "2" |> Core.color { bg: C256 2 },
        "3" |> Core.color { bg: C256 3 },
        "4" |> Core.color { bg: C256 4 },
        "5" |> Core.color { bg: C256 5 },
        "6" |> Core.color { bg: C256 6 },
        "{ fg: Bright Red, bg: Standard Black }" |> Core.color { fg: Bright Red, bg: Standard Black },
        "{ fg: Standard Green, bg: Standard Red }" |> Core.color { fg: Standard Green, bg: Standard Red },
        "{ fg: Bright Yellow, bg: Standard Green }" |> Core.color { fg: Bright Yellow, bg: Standard Green },
        "{ fg: Bright Blue, bg: Bright Yellow }" |> Core.color { fg: Bright Blue, bg: Bright Yellow },
        "{ fg: Bright Magenta, bg: Bright Blue }" |> Core.color { fg: Bright Magenta, bg: Bright Blue },
        "{ fg: Standard Cyan, bg: Bright Magenta }" |> Core.color { fg: Standard Cyan, bg: Bright Magenta },
        "{ fg: Bright White, bg: Standard Cyan }" |> Core.color { fg: Bright White, bg: C16 (Standard Cyan) },
        "Ansi 256 colors",
        "{ fg: LightGray, bg: Cyan }" |> Core.color { fg: C256 (247), bg: C256 (51) },
        "{ fg: DarkGray, bg: Orange }" |> Core.color { fg: C256 (236), bg: C256 (208) },
        "Rgb colors, these aren't supported in all terminals",
        "{ fg: DarkTeal, bg: MintGreen }" |> Core.color { fg: Hex (0x008080), bg: Hex (0x98ff98) },
        "{ fg: DarkTeal, bg: MintGreen }" |> Core.color { fg: Rgb (0, 128, 128), bg: Rgb (152, 255, 152) },
        "{ fg: CoralPink, bg: RoyalBlue }" |> Core.color { fg: Rgb (255, 102, 102), bg: Rgb (65, 105, 225) },
        "{ fg: ElectricPurple, bg: Tangerine }" |> Core.color { fg: Rgb (153, 50, 204), bg: Rgb (255, 165, 0) },
        "{ fg: MintGreen, bg: RaspberryRed }" |> Core.color { fg: Rgb (152, 255, 152), bg: Rgb (219, 68, 83) },
        "{ fg: SunflowerYellow, bg: DarkTeal }" |> Core.color { fg: Rgb (255, 255, 85), bg: Rgb (0, 128, 128) },
        "{ fg: RoyalBlue, bg: Lavender }" |> Core.color { fg: Rgb (65, 105, 225), bg: Rgb (230, 230, 250) },
        "{ fg: Lavender, bg: AquaMarine }" |> Core.color { fg: Rgb (230, 230, 250), bg: Rgb (127, 255, 212) },
        "{ fg: Tangerine, bg: CoralPink }" |> Core.color { fg: Rgb (255, 165, 0), bg: Rgb (255, 102, 102) },
        "{ fg: AquaMarine, bg: SunflowerYellow }" |> Core.color { fg: Rgb (127, 255, 212), bg: Rgb (255, 255, 85) },
        "{ fg: RaspberryRed, bg: ElectricPurple }" |> Core.color { fg: Rgb (219, 68, 83), bg: Rgb (153, 50, 204) },
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
