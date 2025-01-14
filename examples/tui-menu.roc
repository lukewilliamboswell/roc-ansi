app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    ansi: "../package/main.roc",
}

import cli.Stdout
import cli.Stdin
import cli.Tty
import cli.Utc
import ansi.ANSI

Model : {
    screen : ANSI.ScreenSize,
    cursor : ANSI.CursorPosition,
    prevDraw : Utc.Utc,
    currDraw : Utc.Utc,
    things : List Str,
    inputs : List ANSI.Input,
    debug : Bool,
    state : [HomePage, ConfirmPage Str, DoSomething Str, UserExited],
}

init : Model
init = {
    cursor: { row: 3, col: 3 },
    screen: { width: 0, height: 0 },
    prevDraw: Utc.fromMillisSinceEpoch 0,
    currDraw: Utc.fromMillisSinceEpoch 0,
    things: ["Foo", "Bar", "Baz"],
    inputs: List.withCapacity 1000,
    debug: Bool.true,
    state: HomePage,
}

render : Model -> List ANSI.DrawFn
render = \model ->
    # PRESS 'd' to toggle debug screen
    debug = if model.debug then debugScreen model else []

    when model.state is
        ConfirmPage _ ->
            List.join [
                confirmScreen model,
                debug,
            ]

        _ ->
            List.join [
                homeScreen model,
                debug,
            ]

main =

    # TUI Dashboard
    Tty.enableRawMode! {}
    model = Task.loop! init runUILoop
    # Restore terminal
    Stdout.write! (ANSI.toStr Reset)
    Tty.disableRawMode! {}

    # EXIT or RUN selected solution
    when model.state is
        DoSomething selected ->
            Stdout.line "Doing something with $(selected)... now exiting..."

        _ ->
            Stdout.line "Exiting..."

runUILoop : Model -> Task.Task [Step Model, Done Model] _
runUILoop = \prevModel ->

    # Get the time of this draw
    now = Utc.now! {}

    # Update screen size (in case it was resized since the last draw)
    terminalSize = getTerminalSize!

    # Update the model with screen size and time of this draw
    model = { prevModel & screen: terminalSize, prevDraw: prevModel.currDraw, currDraw: now }

    # Draw the screen
    drawFns = render model
    ANSI.drawScreen model drawFns |> Stdout.write!

    # Get user input
    input = Stdin.bytes {} |> Task.map! ANSI.parseRawStdin

    # Parse user input into a command
    command =
        when (input, model.state) is
            (Arrow Up, _) -> MoveCursor Up
            (Arrow Down, _) -> MoveCursor Down
            (Arrow Left, _) -> MoveCursor Left
            (Arrow Right, _) -> MoveCursor Right
            (Lower D, _) -> ToggleDebug
            (Action Enter, HomePage) -> UserToggledScreen
            (Action Enter, ConfirmPage s) -> UserWantToDoSomthing s
            (Action Escape, ConfirmPage _) -> UserToggledScreen
            (Action Escape, _) -> Exit
            (Ctrl C, _) -> Exit
            (Unsupported _, _) -> Nothing
            (_, _) -> Nothing

    # Update model so we can keep a history of user input
    modelWithInput = { model & inputs: List.append model.inputs input }

    # Action command
    when command is
        Nothing -> Task.ok (Step modelWithInput)
        Exit -> Task.ok (Done { modelWithInput & state: UserExited })
        ToggleDebug -> Task.ok (Step { modelWithInput & debug: !modelWithInput.debug })
        MoveCursor direction -> Task.ok (Step (ANSI.updateCursor modelWithInput direction))
        UserWantToDoSomthing s -> Task.ok (Done { modelWithInput & state: DoSomething s })
        UserToggledScreen ->
            when modelWithInput.state is
                HomePage ->
                    result = getSelected modelWithInput

                    when result is
                        Ok selected -> Task.ok (Step { modelWithInput & state: ConfirmPage selected })
                        Err NothingSelected -> Task.ok (Step modelWithInput)

                _ -> Task.ok (Step { modelWithInput & state: HomePage })

mapSelected : Model -> List { selected : Bool, s : Str, row : U16 }
mapSelected = \model ->
    List.mapWithIndex model.things \s, idx ->
        row = 3 + (Num.toU16 idx)
        { selected: model.cursor.row == row, s, row }

getSelected : Model -> Result Str [NothingSelected]
getSelected = \model ->
    mapSelected model
    |> List.keepOks \{ selected, s } -> if selected then Ok s else Err {}
    |> List.first
    |> Result.mapErr \_ -> NothingSelected

getTerminalSize : Task.Task ANSI.ScreenSize _
getTerminalSize =

    # Move the cursor to bottom right corner of terminal
    cmd = [Cursor (Abs { row: 999, col: 999 }), Cursor (Position (Get))] |> List.map Control |> List.map ANSI.toStr |> Str.joinWith ""
    Stdout.write! cmd

    # Read the cursor position
    Stdin.bytes {}
        |> Task.map ANSI.parseCursor
        |> Task.map! \{ row, col } -> { width: col, height: row }

homeScreen : Model -> List ANSI.DrawFn
homeScreen = \model ->
    [
        [
            ANSI.drawCursor { bg: Standard Green },
            ANSI.drawText " Choose your Thing, Toggle debug overlay with 'd'" { r: 1, c: 1, fg: Standard Green },
            ANSI.drawText "RUN" { r: 2, c: 11, fg: Standard Blue },
            ANSI.drawText "QUIT" { r: 2, c: 26, fg: Standard Red },
            ANSI.drawText " ENTER TO RUN, ESCAPE TO QUIT" { r: 2, c: 1, fg: Standard White },
            ANSI.drawBox { r: 0, c: 0, w: model.screen.width, h: model.screen.height },
        ],
        model
        |> mapSelected
        |> List.map \{ selected, s, row } ->
            if selected then
                ANSI.drawText " > $(s)" { r: row, c: 2, fg: Standard Green }
            else
                ANSI.drawText " - $(s)" { r: row, c: 2, fg: Standard Black },
    ]
    |> List.join

confirmScreen : Model -> List ANSI.DrawFn
confirmScreen = \state -> [
    ANSI.drawCursor { bg: Standard Green },
    ANSI.drawText " Would you like to do something?" { r: 1, c: 1, fg: Standard Yellow },
    ANSI.drawText "CONFIRM" { r: 2, c: 11, fg: Standard Blue },
    ANSI.drawText "RETURN" { r: 2, c: 30, fg: Standard Red },
    ANSI.drawText " ENTER TO CONFIRM, ESCAPE TO RETURN" { r: 2, c: 1, fg: Standard White },
    ANSI.drawText " count: TBC" { r: 3, c: 1 },
    ANSI.drawText " speed: TBC" { r: 4, c: 1 },
    ANSI.drawText " size: TBC" { r: 5, c: 1 },
    ANSI.drawBox { r: 0, c: 0, w: state.screen.width, h: state.screen.height },
]

debugScreen : Model -> List ANSI.DrawFn
debugScreen = \state ->
    cursorStr = "CURSOR R$(Num.toStr state.cursor.row), C$(Num.toStr state.cursor.col)"
    screenStr = "SCREEN H$(Num.toStr state.screen.height), W$(Num.toStr state.screen.width)"
    inputDeltaStr = "DELTA $(Num.toStr (Utc.deltaAsMillis state.prevDraw state.currDraw)) millis"
    lastInput =
        state.inputs
        |> List.last
        |> Result.map ANSI.inputToStr
        |> Result.map \str -> "INPUT $(str)"
        |> Result.withDefault "NO INPUT YET"

    [
        ANSI.drawText lastInput { r: state.screen.height - 5, c: 1, fg: Standard Magenta },
        ANSI.drawText inputDeltaStr { r: state.screen.height - 4, c: 1, fg: Standard Magenta },
        ANSI.drawText cursorStr { r: state.screen.height - 3, c: 1, fg: Standard Magenta },
        ANSI.drawText screenStr { r: state.screen.height - 2, c: 1, fg: Standard Magenta },
        ANSI.drawVLine { r: 1, c: state.screen.width // 2, len: state.screen.height, fg: Standard White },
        ANSI.drawHLine { c: 1, r: state.screen.height // 2, len: state.screen.width, fg: Standard White },
    ]
