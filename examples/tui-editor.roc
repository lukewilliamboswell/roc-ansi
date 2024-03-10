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

Grapheme : Str 

Model : {
    screen : ScreenSize,
    cursor : Position,
    lineOffset : U32,

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
        lineOffset: 0,
        filePath,
        original,
        added : List.withCapacity 1000,
        tables :  List.withCapacity 1000 |> List.append firstPieceTable,
    }

render : Model -> List DrawFn
render = \state ->

    # Using the last piece table
    pieceTable : PieceTable Grapheme
    pieceTable = {
        original : state.original,
        added : state.added,
        table : List.first state.tables |> Result.withDefault [],
    }

    # Fuse into a single buffer of Graphemes
    chars : List Grapheme
    chars = PieceTable.toList pieceTable

    # Split into lines on line breaks
    lines : List (List Grapheme)
    lines = splitIntoLines chars [] []

    # Draw functions 
    [
        Core.drawText "ESC to EXIT, CTRL-S TO SAVE" { r: state.screen.height - 1, c: 0, fg: Standard Magenta },
        Core.drawCursor { bg: Standard Green },
        drawViewPort {
            lines,
            lineOffset: state.lineOffset,
            width: state.screen.width,
            height: state.screen.height - 1,
            position: { row: 0, col: 0 },
        },
    ]

# Draw lines into a viewport on the screen
drawViewPort : {
    lines : List (List Grapheme),
    lineOffset: U32,
    width : I32,
    height : I32,
    position : Position,
} -> DrawFn
drawViewPort = \{lines, lineOffset, width, height, position} -> \_, { row, col } ->
    if row < position.row || row >= (position.row + height) || col < position.col || col >= (position.col + width) then
        Err {} # only draw pixels within this viewport
    else

        lineIndex : U64
        lineIndex = Num.intCast (row - position.col + (Num.intCast lineOffset))

        charIndex : U64
        charIndex = Num.intCast (col - position.col)

        line : List Grapheme
        line = List.get lines lineIndex |> Result.withDefault []

        char : Grapheme
        char = List.get line charIndex |> Result.withDefault " "

        Ok { char, fg: Default, bg: Default, styles: [] }

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

    # Parse input into a command
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

    # Handle command
    when command is
        Nothing -> Task.ok (Step model)
        Exit -> Task.ok (Done model)
        MoveCursor direction -> 

            # We dont want the cursor to wrap around the screen, 
            # instead move the lineOffset for the viewPort
            updatedModel =
                if model.cursor.row == 0 && direction == Up then
                    {model & lineOffset: Num.subSaturated model.lineOffset 1}
                else if model.cursor.row == (model.screen.height - 2) && direction == Down then 
                    {model & lineOffset: Num.addSaturated model.lineOffset 1}
                else if model.cursor.col == 0 && direction == Left then 
                    model
                else if model.cursor.col == model.screen.width - 1 && direction == Right then 
                    model
                else
                    Core.updateCursor model direction

            Task.ok (Step updatedModel)

getTerminalSize : Task ScreenSize []_
getTerminalSize =

    # Move the cursor to bottom right corner of terminal
    {} <-  
        [MoveCursor (To { row: 999, col: 999 }), GetCursor] 
        |> List.map Control 
        |> List.map Core.toStr 
        |> Str.joinWith ""
        |> Stdout.write 
        |> Task.await

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

