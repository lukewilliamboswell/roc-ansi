# Roc ANSI Escapes

Helpers for working with terminal escapes

## Examples

Run with `roc run examples/colors.roc`

```sh
[31mRed fg[0m
[32mGreen fg[0m
[34mBlue fg[0m
[41mRed bg[0m
[42mGreen bg[0m
[44mBlue bg[0m
[91m[40m{ fg: BrightRed, bg: Black}[0m
[32m[41m{ fg: Green, bg: Red}[0m
[93m[42m{ fg: BrightYellow, bg: Green}[0m
[94m[103m{ fg: BrightBlue, bg: BrightYellow}[0m
[95m[104m{ fg: BrightMagenta, bg: BrightBlue}[0m
[36m[105m{ fg: Cyan, bg: BrightMagenta}[0m
[97m[46m{ fg: BrightWhite, bg: Cyan}[0m
[39m[49m{ fg: Default, bg: Default}[0m
```
