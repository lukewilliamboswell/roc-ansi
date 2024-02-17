app "styles"
    packages {
        cli: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        ansi: "../package/main.roc",
    }
    imports [cli.Stdout, ansi.Core]
    provides [main] to cli

main =
    [
        "Bold On" |> Core.withStyle [Bold On] |> Core.withStyle [Default],
        "Italicized On" |> Core.withStyle [Italicized On] |> Core.withStyle [Default],
        "Strikethrough On" |> Core.withStyle [Strikethrough On] |> Core.withStyle [Default],
        "Underlined On" |> Core.withStyle [Underlined On] |> Core.withStyle [Default],
        "Combination" |> Core.withStyle [Bold On, Italicized On, Strikethrough On, Underlined On],
        "This should have the last style",
    ]
    |> Str.joinWith "\n"
    |> Stdout.line
