app "tui-menu"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
        unicode: "../../unicode/package/main.roc",
        ansi: "../package/main.roc",
    }
    imports [
        
        # basic-cli platform
        pf.Stdout,
        pf.Stderr,
        pf.Stdin,
        pf.Tty,
        pf.File,
        pf.Arg,
        pf.Path.{Path},
        pf.Task.{ Task },
        pf.Utc.{Utc},

        # Helpers for working with unicode 
        unicode.CodePoint, # temporarily required due to https://github.com/roc-lang/roc/issues/5477
        unicode.Grapheme.{split},

        # Helpers for working with the terminal
        ansi.Core.{ Control, Color, Input, ScreenSize, Position, DrawFn },

        # Used to represent contents while being edited
        PieceTable.{PieceTable, PieceTableEntry},
    ]
    provides [main] to pf

# Alias Str so it is clear that we are working with a single visible "character"
Grapheme : Str 

# Keep track of application state between update->render loop
Model : {

    # Keep track of screen size to handle resizes
    screen : ScreenSize,

    # Keep track of the cursor position
    cursor : Position,

    # Offset the viewPort from the start of file
    lineOffset : U32,

    # Keep track of file saves 
    saveState : [NoChanges, NotSaved, Saved],

    # Path of the file we are editing
    filePath : Path,

    # Buffers for the original file contents, and content appended while editing
    original : List Grapheme,
    added : List Grapheme,

    # Each table records a undo/redo history of edits
    tables : List (List PieceTableEntry),
}

init : List Grapheme, Path -> Model
init = \original, filePath -> 

    # initialise with the contents of the text file we want to edit
    firstPieceTable : List PieceTableEntry
    firstPieceTable = [Original {start : 0, len : List.len original}]

    {
        cursor: { row: 3, col: 3 },
        screen: { width: 0, height: 0 },
        lineOffset: 0,
        saveState: NoChanges,
        filePath,
        original,
        added : List.withCapacity 1000,
        tables :  List.withCapacity 1000 |> List.append firstPieceTable,
    }

render : Model, List (List Grapheme) -> List DrawFn
render = \state, lines ->

    changesCount = state.tables |> List.len |> Num.toStr
    savedMsg = 
        when state.saveState is 
            NoChanges -> "Nothing to save" 
            NotSaved -> "CTRL-S to save $(changesCount) changes"
            Saved -> "Changes saved to $(Path.display state.filePath)" 

    # Draw functions 
    [
        Core.drawText "ESC to EXIT: $(savedMsg)" { r: state.screen.height - 1, c: 0, fg: Standard Magenta },
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

# Prints any unhandled errors to stderr
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

    # TUI Dashboard
    {} <- Tty.enableRawMode |> Task.await
    model <- Task.loop (init original path) runUILoop |> Task.await

    # Restore terminal
    {} <- Stdout.write (Core.toStr Reset) |> Task.await
    {} <- Tty.disableRawMode |> Task.await
    {} <- Stdout.write (Core.toStr (Control (MoveCursor (To { row: 0, col: 0 })))) |> Task.await

    Stdout.line "Finished editing $(Path.display model.filePath)"

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

    # Using the last piece table
    latestTable : PieceTable Grapheme
    latestTable = {
        original : model.original,
        added : model.added,
        table : List.last model.tables |> Result.withDefault [],
    }
 
    # Fuse into a single buffer of Graphemes
    chars : List Grapheme
    chars = PieceTable.toList latestTable

    # Split into lines on line breaks
    lines : List (List Grapheme)
    lines = splitIntoLines chars [] []

    # Draw the screen
    drawFns = render model lines
    {} <- Core.drawScreen model drawFns |> Stdout.write |> Task.await

    # Get user input
    input <- Stdin.bytes |> Task.map Core.parseRawStdin |> Task.await

    # Parse input into a command
    command =
        when input is
            KeyPress Up -> MoveCursor Up
            KeyPress Down -> MoveCursor Down
            KeyPress Left -> MoveCursor Left
            KeyPress Right -> MoveCursor Right
            KeyPress Escape -> Exit
            KeyPress key -> 
                when key is 
                    Space -> InsertCharacter " "
                    Enter -> InsertCharacter "\n"
                    _ -> InsertCharacter (Core.keyToStr key)
            Unsupported _ -> Nothing
            CtrlC -> Exit
            CtrlS -> SaveChanges

    # TODO change to model when shadowing supported
    model2 =
        if model.saveState == Saved then 
            {model & saveState : NoChanges}
        else 
            model

    # Handle command
    when command is
        Nothing -> Task.ok (Step model2)
        Exit -> Task.ok (Done model2)
        InsertCharacter str -> 

            index = calculateCursorIndex lines model.lineOffset model.cursor 0

            {added, table} = PieceTable.insert latestTable { values : [str], index }

            {model2 & tables : List.append model2.tables table, added: added }
            |> \m -> 
                if str == "\n" then 
                    Core.updateCursor m Down
                else 
                    Core.updateCursor m Right
            |> Step
            |> Task.ok

        SaveChanges -> 

            # TODO actually save the changes back to the path
            fileBytes = 
                latestTable 
                |> PieceTable.toList  
                |> List.map Str.toUtf8 
                |> List.join

            {} <- File.writeBytes model.filePath fileBytes 
                |> Task.mapErr UnableToSaveFile
                |> Task.await

            # Update save state 
            Task.ok (Step {model2 & saveState : Saved})

        MoveCursor direction -> 

            # We dont want the cursor to wrap around the screen, 
            # instead move the lineOffset for the viewPort
            model3 =
                if model2.cursor.row == 0 && direction == Up then
                    {model2 & lineOffset: Num.subSaturated model2.lineOffset 1}
                else if model2.cursor.row == (model2.screen.height - 2) && direction == Down then 
                    {model2 & lineOffset: Num.addSaturated model2.lineOffset 1}
                else if model2.cursor.col == 0 && direction == Left then 
                    model2
                else if model2.cursor.col == model2.screen.width - 1 && direction == Right then 
                    model2
                else
                    Core.updateCursor model2 direction

            Task.ok (Step model3)

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

# Helper to split grepheme's on line breaks
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

calculateCursorIndex : List (List Grapheme), U32, {row : I32, col : I32 }, U64 -> U64
calculateCursorIndex = \lines, lineOffset, cursor, acc -> 
    if lineOffset > 0 then 
        # add the length of each line that isn't displayed (before viewport)
        when lines is 
            [] -> acc
            [first, .. as rest] -> calculateCursorIndex rest (lineOffset - 1) cursor (acc + List.len first + 1)
    else
        when lines is
            [] -> acc
            [first, .. as rest] if cursor.row > 0 -> calculateCursorIndex rest 0 {cursor & row: cursor.row - 1} (acc + List.len first + 1)
            [first, .. as rest] -> 
                acc + (Num.min (List.len first) (Num.intCast cursor.col))
