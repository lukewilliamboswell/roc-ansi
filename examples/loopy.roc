app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.13.0/nW9yMRtZuCYf1Oa9vbE5XoirMwzLbtoSgv7NGhUlqYA.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import cli.Stdin
import cli.Tty
import cli.Task exposing [Task]
import cli.Http
import ansi.Core
import ansi.Draw

Model : {
    cursor : Draw.Position,
    screen: Draw.ScreenSize,
    virtual: Draw.VirtualScreen,
}

init : Model
init = {
    cursor: { row: 3, col: 3 },
    screen: {width:0, height:0},
    virtual: Draw.empty,
}

render : Model -> List Draw.DrawFn
render = \model ->
    [
        Draw.pixel { row: 1, col: 1 } { char: "A" },
        Draw.pixel { row: 1, col: model.screen.width } { char: "B" },
        Draw.pixel { row: model.screen.height, col: 1  } { char: "C" },
        Draw.pixel { row: model.screen.height, col: model.screen.width } { char: "D" },
        Draw.pixel model.cursor { char: "X" },
        #Draw.box { r : 0, c : 0, w : size.width, h : size.height, fg : Standard Blue, bg: Standard White },
    ]

main =
    Tty.enableRawMode!
    _ = Task.loop! init runUILoop
    Tty.disableRawMode!
    Stdout.write! (Core.toStr Reset)

    Stdout.line "Exiting..."

runUILoop : Model -> Task.Task [Step Model, Done Model] _
runUILoop = \prevModel ->

    screen = getTerminalSize!

    model = { prevModel &
        screen,
        virtual: Draw.render screen (render prevModel),
    }

    (output, _) = Draw.draw prevModel.virtual model.virtual

    # note this is 1-based -- let's make a helper so people don't get caught out
    #Stdout.write! (Core.toStr (Control (Erase (Display All))))
    Stdout.write! (Core.toStr (Control (Cursor (Abs { row: 1, col: 1 }))))
    Stdout.write! output

    # log the output to an echo server... to help debug things
    # escape the 'ESC' character so it doesn't mess up things when displayed in a terminal
    _ =
        { Http.defaultRequest &
            url: "http://127.0.0.1:8000",
            body: output |> Str.replaceEach "\u(0001)" "ESC" |> Str.toUtf8 ,
        }
        |> Http.send!

    # Get user input
    input = Stdin.bytes |> Task.map! Core.parseRawStdin

    # Parse user input into a command
    command =
        when (input, model) is
            (Arrow Up, _) -> MoveCursor Up
            (Arrow Down, _) -> MoveCursor Down
            (Arrow Left, _) -> MoveCursor Left
            (Arrow Right, _) -> MoveCursor Right
            #(Lower D, _) -> ToggleDebug
            #(Action Enter, HomePage) -> UserToggledScreen
            #(Action Enter, ConfirmPage s) -> UserWantToDoSomthing s
            #(Action Escape, ConfirmPage _) -> UserToggledScreen
            #(Action Escape, _) -> Exit
            (Ctrl C, _) -> Exit
            #(Unsupported _, _) -> Nothing
            (_, _) -> Nothing

    # Action command
    when command is
        Nothing -> Task.ok (Step model)
        Exit -> Task.ok (Done model)
        MoveCursor direction -> Task.ok (Step (Core.updateCursor model direction))

getTerminalSize : Task.Task Core.ScreenSize _
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
    |> Task.map! \{ row, col } -> { width: col, height: row }
