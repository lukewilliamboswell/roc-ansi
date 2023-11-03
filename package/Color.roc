interface Color
    exposes [Color, fg, bg, with]
    imports []

Color : [   
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    BrightBlack, # for terminals which support axiterm specification    
    BrightRed, # for terminals which support axiterm specification  
    BrightGreen, # for terminals which support axiterm specification    
    BrightYellow, # for terminals which support axiterm specification   
    BrightBlue, # for terminals which support axiterm specification 
    BrightMagenta, # for terminals which support axiterm specification  
    BrightCyan, # for terminals which support axiterm specification 
    BrightWhite, # for terminals which support axiterm specification    
    Default,
]

# ESC character
esc : Str
esc = "\u(001b)"

fgFromColor : Color -> Str
fgFromColor = \color ->
    when color is
        Black -> "\(esc)[30m"
        Red -> "\(esc)[31m"
        Green -> "\(esc)[32m"
        Yellow -> "\(esc)[33m"
        Blue -> "\(esc)[34m"
        Magenta -> "\(esc)[35m"
        Cyan -> "\(esc)[36m"
        White -> "\(esc)[37m"
        Default -> "\(esc)[39m"
        BrightBlack -> "\(esc)[90m"
        BrightRed -> "\(esc)[91m"
        BrightGreen -> "\(esc)[92m"
        BrightYellow -> "\(esc)[93m"
        BrightBlue -> "\(esc)[94m"
        BrightMagenta -> "\(esc)[95m"
        BrightCyan -> "\(esc)[96m"
        BrightWhite -> "\(esc)[97m"

bgFromColor : Color -> Str
bgFromColor = \color ->
    when color is
        Black -> "\(esc)[40m"
        Red -> "\(esc)[41m"
        Green -> "\(esc)[42m"
        Yellow -> "\(esc)[43m"
        Blue -> "\(esc)[44m"
        Magenta -> "\(esc)[45m"
        Cyan -> "\(esc)[46m"
        White -> "\(esc)[47m"
        Default -> "\(esc)[49m"
        BrightBlack -> "\(esc)[100m"
        BrightRed -> "\(esc)[101m"
        BrightGreen -> "\(esc)[102m"
        BrightYellow -> "\(esc)[103m"
        BrightBlue -> "\(esc)[104m"
        BrightMagenta -> "\(esc)[105m"
        BrightCyan -> "\(esc)[106m"
        BrightWhite -> "\(esc)[107m"

## Adds foreground color formatting to a Str and resets after
fg : Str, Color -> Str
fg = \str, color -> "\(fgFromColor color)\(str)\(esc)[0m"

## Adds background color formatting to a Str and resets after
bg : Str, Color -> Str
bg = \str, color -> "\(bgFromColor color)\(str)\(esc)[0m"

## Adds color formatting to a Str and resets after
with : Str, {fg: Color, bg: Color} -> Str
with = \str, colors -> "\(fgFromColor colors.fg)\(bgFromColor colors.bg)\(str)\(esc)[0m"
