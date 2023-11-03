# Roc ANSI Escapes

Helpers for working with terminal escapes

## Examples

Run with `roc run examples/colors.roc`

I have the following shell output which normally renders with colors when displayed in a terminal. But I want to display this in markdown rendered in the browser. Are you able to convert this to html that will render the colors?

<p><span style="color: red;">Red fg</span></p>
<p><span style="color: green;">Green fg</span></p>
<p><span style="color: blue;">Blue fg</span></p>
<p><span style="background-color: red;">Red bg</span></p>
<p><span style="background-color: green;">Green bg</span></p>
<p><span style="background-color: blue;">Blue bg</span></p>
<p><span style="color: #ff6f6f; background-color: black;">{ fg: BrightRed, bg: Black}</span></p>
<p><span style="color: green; background-color: red;">{ fg: Green, bg: Red}</span></p>
<p><span style="color: #ffff54; background-color: green;">{ fg: BrightYellow, bg: Green}</span></p>
<p><span style="color: #6f6fff; background-color: #ffff6f;">{ fg: BrightBlue, bg: BrightYellow}</span></p>
<p><span style="color: #ff6fff; background-color: #6f6fff;">{ fg: BrightMagenta, bg: BrightBlue}</span></p>
<p><span style="color: cyan; background-color: #ff6fff;">{ fg: Cyan, bg: BrightMagenta}</span></p>
<p><span style="color: #ffffff; background-color: cyan;">{ fg: BrightWhite, bg: Cyan}</span></p>
<p><span style="color: black; background-color: white;">{ fg: Default, bg: Default}</span></p>

