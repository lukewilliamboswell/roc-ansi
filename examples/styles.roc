app "styles"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
        ansi: "../package/main.roc",
    }
    imports [cli.Task, cli.Stdout, ansi.Core]
    provides [main] to cli

main =
    [
        "Bold On" |> Core.withStyle [Bold On] |> Core.withStyle [Default],
        "Faint On" |> Core.withStyle [Faint On] |> Core.withStyle [Default],
        "Italic On" |> Core.withStyle [Italic On] |> Core.withStyle [Default], # TODO why is bold not kept after using italic?
        "Overline On" |> Core.withStyle [Overline On] |> Core.withStyle [Default],
        "Strikethrough On" |> Core.withStyle [Strikethrough On] |> Core.withStyle [Default],
        "Underline On" |> Core.withStyle [Underline On] |> Core.withStyle [Default],
        "Invert On" |> Core.withStyle [Invert On] |> Core.withStyle [Default],
        "Blink Slow" |> Core.withStyle [Blink Slow] |> Core.withStyle [Default],
        "Blink Rapid" |> Core.withStyle [Blink Rapid] |> Core.withStyle [Default],
        "Combination" |> Core.withStyle [Bold On, Italic On, Strikethrough On, Underline On],
        "This should have the last style",
        "This shouldn't have any style" |> Core.withStyle [Default],
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
