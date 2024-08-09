app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.12.0/Lb8EgiejTUzbggO2HVVuPJFkwvvsfW6LojkLR20kTVE.tar.br",
    ansi: "../package/main.roc",
}

import cli.Task
import cli.Stdout
import ansi.Core

main =
    [
        "Bold On" |> Core.style [Bold On] |> Core.style [Default],
        "Faint On" |> Core.style [Faint On] |> Core.style [Default],
        "Italic On" |> Core.style [Italic On] |> Core.style [Default],
        "Strikethrough On" |> Core.style [Strikethrough On] |> Core.style [Default],
        "Underline On" |> Core.style [Underline On] |> Core.style [Default],
        "Invert On" |> Core.style [Invert On] |> Core.style [Default],
        "Combination" |> Core.style [Bold On, Italic On, Strikethrough On, Underline On],
        "This should have the last style",
        "This shouldn't have any style" |> Core.style [Default],
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
