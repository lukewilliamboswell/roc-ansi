app "tui-menu"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        ansi: "../package/main.roc",
    }
    imports [
        pf.Stdout,
        pf.Stderr,
        pf.Stdin,
        pf.Tty,
        pf.File,
        pf.Arg,
        pf.Path.{Path},
        pf.Task.{ Task },
        ansi.Core.{ Control, Color, Input, ScreenSize, Position, DrawFn },
        pf.Utc.{ Utc },
    ]
    provides [main] to pf

PieceBufferIndex : {start : U64, end : U64}
PieceTableEntry : [Add PieceBufferIndex, Original PieceBufferIndex]
PieceTable : List PieceTableEntry

Model : {
    screen : ScreenSize,
    cursor : Position,
    prevDraw : Utc,
    currDraw : Utc,
    things : List Str,
    inputs : List Input,
    debug : Bool,
    state : [HomePage, ConfirmPage Str, DoSomething Str, UserExited],
    original : List U8,
    added : List U8,
    tables : List PieceTable,
}

init : List U8 -> Model
init = \original -> 

    # initialise with the contents of the text file we want to edit
    firstPieceTable : PieceTable
    firstPieceTable = [Original {start : 0, end : List.len original}]

    {
        cursor: { row: 3, col: 3 },
        screen: { width: 0, height: 0 },
        prevDraw: Utc.fromMillisSinceEpoch 0,
        currDraw: Utc.fromMillisSinceEpoch 0,
        things: ["Foo", "Bar", "Baz"],
        inputs: List.withCapacity 1000,
        debug: Bool.true,
        state: HomePage,
        original,
        added : [],
        tables : [firstPieceTable],
    }

render : Model -> List DrawFn
render = \state ->
    # PRESS 'd' to toggle debug screen
    debug = if state.debug then debugScreen state else []

    when state.state is
        ConfirmPage _ ->
            List.join [
                confirmScreen state,
                debug,
            ]

        _ ->
            List.join [
                homeScreen state,
                debug,
            ]

main : Task {} I32
main = runTask |> Task.onErr handleErr

# Handle any unhandled errors by just reporting to stderr
handleErr : _ -> Task {} I32
handleErr = \err ->

    errorLabel = Core.withFg "ERROR" (Standard Red)
    errorMessage = Inspect.toStr err

    {} <- Stderr.line "$(errorLabel) $(errorMessage)" |> Task.await

    Task.err 1

runTask : Task {} _
runTask =

    # Read path of file to edit from argument
    path <- readArgFilePath |> Task.await

    # Read the file  
    original <- 
        File.readBytes path 
        |> Task.mapErr UnableToOpenFile 
        |> Task.await

    # TUI Dashboard
    {} <- Tty.enableRawMode |> Task.await
    model <- Task.loop (init original) runUILoop |> Task.await

    # Restore terminal
    {} <- Stdout.write (Core.toStr Reset) |> Task.await
    {} <- Tty.disableRawMode |> Task.await

    # EXIT or RUN selected solution
    when model.state is
        DoSomething selected ->
            Stdout.line "Doing something with $(selected)... now exiting..."

        _ ->
            Stdout.line "Exiting..."

readArgFilePath : Task Path _ 
readArgFilePath = 
    args <- Arg.list |> Task.attempt
        
    when args is
        Ok ([ _, pathStr, .. ]) ->
            Task.ok (Path.fromStr pathStr)
        _ ->
            Task.err (FailedToReadArgs "expected file argument e.g. 'roc run tui-editor.roc -- file.txt'")

runUILoop : Model -> Task [Step Model, Done Model] []_
runUILoop = \prevModel ->

    # Get the time of this draw
    now <- Utc.now |> Task.await

    # Update screen size (in case it was resized since the last draw)
    terminalSize <- getTerminalSize |> Task.await

    # Update the model with screen size and time of this draw
    model = { prevModel & screen: terminalSize, prevDraw: prevModel.currDraw, currDraw: now }

    # Draw the screen
    drawFns = render model
    {} <- Core.drawScreen model drawFns |> Stdout.write |> Task.await

    # Get user input
    input <- Stdin.bytes |> Task.map Core.parseRawStdin |> Task.await

    # Parse user input into a command
    command =
        when (input, model.state) is
            (KeyPress Up, _) -> MoveCursor Up
            (KeyPress Down, _) -> MoveCursor Down
            (KeyPress Left, _) -> MoveCursor Left
            (KeyPress Right, _) -> MoveCursor Right
            (KeyPress LowerD, _) -> ToggleDebug
            (KeyPress Enter, HomePage) -> UserToggledScreen
            (KeyPress Enter, ConfirmPage s) -> UserWantToDoSomthing s
            (KeyPress Escape, ConfirmPage _) -> UserToggledScreen
            (KeyPress Escape, _) -> Exit
            (KeyPress _, _) -> Nothing
            (Unsupported _, _) -> Nothing
            (CtrlC, _) -> Exit

    # Update model so we can keep a history of user input
    modelWithInput = { model & inputs: List.append model.inputs input }

    # Action command
    when command is
        Nothing -> Task.ok (Step modelWithInput)
        Exit -> Task.ok (Done { modelWithInput & state: UserExited })
        ToggleDebug -> Task.ok (Step { modelWithInput & debug: !modelWithInput.debug })
        MoveCursor direction -> Task.ok (Step (Core.updateCursor modelWithInput direction))
        UserWantToDoSomthing s -> Task.ok (Done { modelWithInput & state: DoSomething s })
        UserToggledScreen ->
            when modelWithInput.state is
                HomePage ->
                    result = getSelected modelWithInput

                    when result is
                        Ok selected -> Task.ok (Step { modelWithInput & state: ConfirmPage selected })
                        Err NothingSelected -> Task.ok (Step modelWithInput)

                _ -> Task.ok (Step { modelWithInput & state: HomePage })

mapSelected : Model -> List { selected : Bool, s : Str, row : I32 }
mapSelected = \model ->
    s, idx <- List.mapWithIndex model.things

    row = 3 + (Num.toI32 idx)

    { selected: model.cursor.row == row, s, row }

getSelected : Model -> Result Str [NothingSelected]
getSelected = \model ->
    mapSelected model
    |> List.keepOks \{ selected, s } -> if selected then Ok s else Err {}
    |> List.first
    |> Result.mapErr \_ -> NothingSelected

getTerminalSize : Task ScreenSize []_
getTerminalSize =

    # Move the cursor to bottom right corner of terminal
    cmd = [MoveCursor (To { row: 999, col: 999 }), GetCursor] |> List.map Control |> List.map Core.toStr |> Str.joinWith ""
    {} <- Stdout.write cmd |> Task.await

    # Read the cursor position
    Stdin.bytes
    |> Task.map Core.parseCursor
    |> Task.map \{ row, col } -> { width: col, height: row }

homeScreen : Model -> List DrawFn
homeScreen = \model ->
    [
        [
            Core.drawCursor { bg: Standard Green },
            Core.drawText " Choose your Thing, Toggle debug overlay with 'd'" { r: 1, c: 1, fg: Standard Green },
            Core.drawText "RUN" { r: 2, c: 11, fg: Standard Blue },
            Core.drawText "QUIT" { r: 2, c: 26, fg: Standard Red },
            Core.drawText " ENTER TO RUN, ESCAPE TO QUIT" { r: 2, c: 1, fg: Standard White },
            Core.drawBox { r: 0, c: 0, w: model.screen.width, h: model.screen.height },
        ],
        { selected, s, row } <- model |> mapSelected |> List.map

        if selected then
            Core.drawText " > $(s)" { r: row, c: 2, fg: Standard Green }
        else
            Core.drawText " - $(s)" { r: row, c: 2, fg: Standard Black },
    ]
    |> List.join

confirmScreen : Model -> List DrawFn
confirmScreen = \state -> [
    Core.drawCursor { bg: Standard Green },
    Core.drawText " Would you like to do something?" { r: 1, c: 1, fg: Standard Yellow },
    Core.drawText "CONFIRM" { r: 2, c: 11, fg: Standard Blue },
    Core.drawText "RETURN" { r: 2, c: 30, fg: Standard Red },
    Core.drawText " ENTER TO CONFIRM, ESCAPE TO RETURN" { r: 2, c: 1, fg: Standard White },
    Core.drawText " count: TBC" { r: 3, c: 1 },
    Core.drawText " speed: TBC" { r: 4, c: 1 },
    Core.drawText " size: TBC" { r: 5, c: 1 },
    Core.drawBox { r: 0, c: 0, w: state.screen.width, h: state.screen.height },
]

debugScreen : Model -> List DrawFn
debugScreen = \state ->
    cursorStr = "CURSOR R$(Num.toStr state.cursor.row), C$(Num.toStr state.cursor.col)"
    screenStr = "SCREEN H$(Num.toStr state.screen.height), W$(Num.toStr state.screen.width)"
    inputDeltaStr = "DELTA $(Num.toStr (Utc.deltaAsMillis state.prevDraw state.currDraw)) millis"
    lastInput =
        state.inputs
        |> List.last
        |> Result.map Core.inputToStr
        |> Result.map \str -> "INPUT $(str)"
        |> Result.withDefault "NO INPUT YET"

    [
        Core.drawText lastInput { r: state.screen.height - 5, c: 1, fg: Standard Magenta },
        Core.drawText inputDeltaStr { r: state.screen.height - 4, c: 1, fg: Standard Magenta },
        Core.drawText cursorStr { r: state.screen.height - 3, c: 1, fg: Standard Magenta },
        Core.drawText screenStr { r: state.screen.height - 2, c: 1, fg: Standard Magenta },
        Core.drawVLine { r: 1, c: state.screen.width // 2, len: state.screen.height, fg: Standard White },
        Core.drawHLine { c: 1, r: state.screen.height // 2, len: state.screen.width, fg: Standard White },
    ]
