app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.12.0/Lb8EgiejTUzbggO2HVVuPJFkwvvsfW6LojkLR20kTVE.tar.br",
    ansi: "../package/main.roc",
}

import cli.Task exposing [Task]
import cli.Stdout
import cli.Stdin
import cli.Tty
import ansi.Draw
import ansi.Core

main =

    # we need raw mode enables to get the terminal size
    # using a Task
    Tty.enableRawMode!
    size = getTerminalSize!
    Tty.disableRawMode!

    # not strictly necessary, but gets us the expected behaviour
    Stdout.write! (Core.toStr (Control (Erase (Display All))))

    # note this is 1-based -- let's make a helper so people don't get caught out
    Stdout.write! (Core.toStr (Control (Cursor (Abs { row: 1, col: 1 }))))

    # render our screen using a list draw of functions
    firstScreen =
        Draw.render
            size
            [
                Draw.pixel {row:5,col:5} { char: "X" },
                Draw.box { r : 0, c : 0, w : size.width, h : size.height, fg : Standard Blue, bg: Standard White },
                #Draw.clear {fg: Default},
            ]

    # diff this against the previous screen (here we are using an empty screen)
    #(_, _) = Draw.draw Draw.empty firstScreen

    # write the output including ANSI control codes to stdout
    #Stdout.write! output1

    # render our screen using a list draw of functions
    secondScreen =
        Draw.render
            size
            [
                Draw.pixel {row:10,col:10} { char: "X" },
                Draw.box { r : 0, c : 0, w : size.width, h : size.height, fg : Standard Blue },
            ]

    # diff this against the previous screen
    (output2, _) = Draw.draw firstScreen secondScreen

    # move the cursor back to the starting position
    #Stdout.write! (Core.toStr (Control (Cursor (Abs { row: 0, col: 0 }))))
    Stdout.write! "\u(000b)[1;1H"

    # write the output including ANSI control codes to stdout
    Stdout.write! output2

    # reset the terminal so it continues behaving as expected
    #Stdout.write! (Core.toStr Reset)

    #Stdout.write! (Core.toStr (Control (Cursor (Abs { row: 0, col: 0 }))))

# Get the size of the terminal window
# when Task is a builtin, this can be moved into the package
getTerminalSize : Task.Task Core.ScreenSize []_
getTerminalSize =

    # Move the cursor to bottom right corner of terminal
    [Cursor (Abs { row: 999, col: 999 }), Cursor (Position (Get))]
    |> List.map Control
    |> List.map Core.toStr
    |> Str.joinWith ""
    |> Stdout.write!

    # Read the cursor position
    Stdin.bytes
    |> Task.map Core.parseCursor
    |> Task.map \{ row, col } -> { width: col, height: row }
