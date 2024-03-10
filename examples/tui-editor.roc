app "tui-menu"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        unicode: "../../unicode/package/main.roc",
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
        unicode.CodePoint, # temporarily required due to https://github.com/roc-lang/roc/issues/5477
        unicode.Grapheme.{split},
        ansi.Core.{ Control, Color, Input, ScreenSize, Position, DrawFn },
        PieceTable.{PieceTable, PieceTableEntry},
    ]
    provides [main] to pf

drawViewPort : PieceTable Grapheme -> DrawFn
drawViewPort = \pieceTable -> 

    # fuse buffers into a single buffer of Graphemes
    chars : List Grapheme
    chars = PieceTable.toList pieceTable

    lines : List (List Grapheme)
    lines = splitIntoLines chars [] []

    # index into graphemes for draw function
    \_, { row, col } ->

        line : List Grapheme
        line = List.get lines (Num.intCast row) |> Result.withDefault []

        char : Grapheme
        char = List.get line (Num.intCast col) |> Result.withDefault " "

        Ok { char, fg: Default, bg: Default, styles: [Bold Off] }

Grapheme : Str 

Model : {
    screen : ScreenSize,
    cursor : Position,

    # Path of the file we are editing
    filePath : Str,

    # Buffers for the original file contents, and content appended while editing
    original : List Grapheme,
    added : List Grapheme,

    # Each table records a undo/redo history of edits
    tables : List (List PieceTableEntry),
}

init : List Grapheme, Str -> Model
init = \original, filePath -> 

    # initialise with the contents of the text file we want to edit
    firstPieceTable : List PieceTableEntry
    firstPieceTable = [Original {start : 0, len : List.len original}]

    {
        cursor: { row: 3, col: 3 },
        screen: { width: 0, height: 0 },
        filePath,
        original,
        added : List.withCapacity 1000,
        tables :  List.withCapacity 1000 |> List.append firstPieceTable,
    }

render : Model -> List DrawFn
render = \state ->
    [
        Core.drawText "EDITING $(state.filePath), ESC to EXIT" { r: state.screen.height - 1, c: 0, fg: Standard Magenta },
        Core.drawCursor { bg: Standard Green },
        drawViewPort {
            original : state.original,
            added : state.added,
            table : List.first state.tables |> Result.withDefault [],
        },
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

    # Read the file, split into extended grapheme clusters
    original <- 
        File.readUtf8 path 
        |> Task.mapErr UnableToOpenFile 
        |> Task.await \fileContents ->
            fileContents
            |> split
            |> Task.fromResult
            |> Task.mapErr UnableToSplitIntoGraphemes
        |> Task.await

    filePath = Path.display path

    # TUI Dashboard
    {} <- Tty.enableRawMode |> Task.await
    model <- Task.loop (init original filePath) runUILoop |> Task.await

    # Restore terminal
    {} <- Stdout.write (Core.toStr Reset) |> Task.await
    {} <- Tty.disableRawMode |> Task.await

    Stdout.line "Saving any changes to $(model.filePath)"

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

    # Update screen size (in case it was resized since the last draw)
    terminalSize <- getTerminalSize |> Task.await

    # Update the model with screen size and time of this draw
    model = { prevModel & screen: terminalSize }

    # Draw the screen
    drawFns = render model
    {} <- Core.drawScreen model drawFns |> Stdout.write |> Task.await

    # Get user input
    input <- Stdin.bytes |> Task.map Core.parseRawStdin |> Task.await

    # Parse user input into a command
    command =
        when (input) is
            KeyPress Up -> MoveCursor Up
            KeyPress Down -> MoveCursor Down
            KeyPress Left -> MoveCursor Left
            KeyPress Right -> MoveCursor Right
            KeyPress Escape -> Exit
            KeyPress _ -> Nothing
            Unsupported _ -> Nothing
            CtrlC -> Exit

    # Action command
    when command is
        Nothing -> Task.ok (Step model)
        Exit -> Task.ok (Done model)
        MoveCursor direction -> Task.ok (Step (Core.updateCursor model direction))

getTerminalSize : Task ScreenSize []_
getTerminalSize =

    # Move the cursor to bottom right corner of terminal
    cmd = [MoveCursor (To { row: 999, col: 999 }), GetCursor] |> List.map Control |> List.map Core.toStr |> Str.joinWith ""
    {} <- Stdout.write cmd |> Task.await

    # Read the cursor position
    Stdin.bytes
    |> Task.map Core.parseCursor
    |> Task.map \{ row, col } -> { width: col, height: row }

splitIntoLines : List Grapheme, List Grapheme, List (List Grapheme) -> List (List Grapheme)
splitIntoLines = \chars, line, lines ->
    when chars is 
        [] if List.isEmpty line -> lines
        [] -> List.append lines line
        [a, .. as rest] if a == "\r\n" || a == "\n" -> splitIntoLines rest [] (List.append lines line)
        [a, .. as rest] -> splitIntoLines rest (List.append line a) lines

expect splitIntoLines [] [] [] == []
expect splitIntoLines ["f","o","o"] [] [] == [["f","o","o"]]
expect splitIntoLines ["f","o","o","\r\n","b","a","r"] [] [] == [["f","o","o"],["b","a","r"]]

