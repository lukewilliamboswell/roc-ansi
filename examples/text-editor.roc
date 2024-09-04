app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    ansi: "../package/main.roc",

    # TODO use unicode when https://github.com/roc-lang/roc/issues/5477 resolved
    # unicode: "https://github.com/roc-lang/unicode/releases/download/0.1.1/-FQDoegpSfMS-a7B0noOnZQs3-A2aq9RSOR5VVLMePg.tar.br",
}

# Platform basic-cli provides the effects for working with files
import cli.Stdout
import cli.Stdin
import cli.Tty
import cli.Arg
import cli.Path
# Package with helpers for working with the terminal
import ansi.Core
import ansi.PieceTable

# Helpers for working with unicode
# TODO use unicode when https://github.com/roc-lang/roc/issues/5477 resolved
# import unicode.CodePoint
# import unicode.Grapheme exposing [split]

# TODO replace with unicode package when https://github.com/roc-lang/roc/issues/5477 resolved
# This is a temporary helper to split a file that only contains ASCII text.
#
# Due to this work around this editor DOES NOT support unicode.
#
# This is required as the above bug prevents CI from running.
split : Str -> Result (List Str) []
split = \in ->
    in
    |> Str.toUtf8
    |> List.keepOks \char -> Str.fromUtf8 [char]
    |> Ok

# We are working with a single visible "character", let's use an alias to help with type checking
Grapheme : Str

# Keep track of application state between update->render loop
Model : {
    # Keep track of screen size to handle resizes
    screen : Core.ScreenSize,

    # Keep track of the cursor position
    cursor : Core.CursorPosition,

    # Offset the viewPort from the start of file
    lineOffset : U16,

    # Keep track of file saves
    saveState : [NoChanges, NotSaved, Saved],

    # Path of the file we are editing
    filePath : Path.Path,

    # Buffers for the original file contents, and content appended while editing
    original : List Grapheme,
    added : List Grapheme,

    # Two tables to record undo/redo history of edits
    history : List (List PieceTable.Entry),
    future : List (List PieceTable.Entry),
}

# Initilise the application state
init : List Grapheme, Path.Path -> Model
init = \original, filePath ->

    # initialise with the contents of the text file we want to edit
    firstPieceTable : List PieceTable.Entry
    firstPieceTable = [Original { start: 0, len: List.len original }]

    {
        cursor: { row: 3, col: 3 },
        screen: { width: 0, height: 0 },
        lineOffset: 0,
        saveState: NoChanges,
        filePath,
        original,
        added: List.withCapacity 1000,
        history: List.withCapacity 1000 |> List.append firstPieceTable,
        future: [],
    }

# Render the screen after each update
render : Model, List (List Grapheme) -> List Core.DrawFn
render = \state, lines ->

    changesCount = List.len state.history - 1 |> Num.toStr
    redoMsg = if List.len state.future > 0 then ", CTRL-Y to Redo changes" else ""
    savedMsg =
        when state.saveState is
            NoChanges -> "Nothing to save$(redoMsg)"
            NotSaved -> "CTRL-S to save $(changesCount) changes, CTRL-Z to Undo changes$(redoMsg)"
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
drawViewPort :
    {
        lines : List (List Grapheme),
        lineOffset : U16,
        width : U16,
        height : U16,
        position : Core.CursorPosition,
    }
    -> Core.DrawFn
drawViewPort = \{ lines, lineOffset, width, height, position } -> \_, { row, col } ->
        if row < position.row || row >= (position.row + height) || col < position.col || col >= (position.col + width) then
            Err {} # only draw pixels within this viewport
        else
            lineIndex : U64
            lineIndex = Num.intCast (row - position.col + (Num.intCast lineOffset))

            charIndex : U64
            charIndex = Num.intCast (col - position.col)

            when List.get lines lineIndex is
                Err OutOfBounds ->
                    # if the viewport has lines that are outside the buffer, just render blank spaces
                    Ok { char: " ", fg: Default, bg: Default, styles: [] }

                Ok line ->
                    if charIndex == List.len line then
                        # render "¶" so users can see line breaks
                        Ok { char: "¶", fg: Standard Cyan, bg: Default, styles: [] }
                    else
                        char : Grapheme
                        char = List.get line charIndex |> Result.withDefault " "
                        Ok { char, fg: Default, bg: Default, styles: [] }

main =

    # Read path of file to edit from argument
    path = readArgFilePath!

    # Check if the file exists
    fileExists =
        Path.isFile path
        |> Task.onErr! \err ->
            if err == PathDoesNotExist then
                Task.ok Bool.false
            else
                Task.err UnableToCheckFile

    # Read the file
    original = getFileContentsTask! { fileExists, path }

    # Loop UI command->update->render
    Tty.enableRawMode! {}
    model = Task.loop! (init original path) runUILoop

    # Restore terminal
    Stdout.write! (Core.toStr Reset)
    Tty.disableRawMode! {}
    Stdout.write! (Core.toStr (Control (Cursor (Abs { row: 0, col: 0 }))))

    Stdout.line "Finished editing $(Path.display model.filePath)"

# A task that will read the file contents, split into extended grapheme clusters
getFileContentsTask : { fileExists : Bool, path : Path.Path } -> Task.Task (List Grapheme) _
getFileContentsTask = \{ fileExists, path } ->
    if fileExists then
        Path.readUtf8 path
        |> Task.mapErr UnableToOpenFile
        |> Task.await \fileContents ->
            fileContents
            |> split
            |> Task.fromResult
            |> Task.mapErr UnableToSplitIntoGraphemes
    else
        Task.ok [] # file doesn't exist, we will write to it when we save

# Get the file path from the first argument
readArgFilePath : Task.Task Path.Path _
readArgFilePath =
    args = Arg.list! {}
    when args is
        [_, pathStr, ..] -> Task.ok (Path.fromStr pathStr)
        _ -> Task.err (FailedToReadArgs "expected file argument e.g. 'roc run tui-editor.roc -- file.txt'")

# UI Loop command->update->render
runUILoop : Model -> Task.Task [Step Model, Done Model] []_
runUILoop = \prevModel ->

    # Update screen size (in case it was resized since the last draw)
    terminalSize = getTerminalSize!

    # Update the model with screen size and time of this draw
    model = { prevModel & screen: terminalSize }

    # Use the current selected piece table
    currentTable : PieceTable.PieceTable Grapheme
    currentTable = {
        original: model.original,
        added: model.added,
        table: List.last model.history |> Result.withDefault [],
    }

    # Fuse into a single buffer of Graphemes
    chars : List Grapheme
    chars = PieceTable.toList currentTable

    # Split into lines on line breaks
    lines : List (List Grapheme)
    lines = splitIntoLines chars [] []

    # Draw the screen
    drawFns = render model lines
    Core.drawScreen model drawFns |> Stdout.write!

    # Get user input
    input = Stdin.bytes {} |> Task.map! Core.parseRawStdin

    # Parse input into a command
    command =
        when input is
            Arrow Up -> MoveCursor Up
            Arrow Down -> MoveCursor Down
            Arrow Left -> MoveCursor Left
            Arrow Right -> MoveCursor Right
            Action Escape -> Exit
            Action Delete -> DeleteUnderCursor
            Action Space -> InsertCharacter " "
            Action Enter -> InsertCharacter "\n"
            Symbol symbol -> InsertCharacter (Core.symbolToStr symbol)
            Ctrl C -> Exit
            Ctrl S -> SaveChanges
            Ctrl Y -> RedoChanges
            Ctrl Z -> UndoChanges
            Unsupported key -> crash (Inspect.toStr key)
            _ -> Nothing

    # TODO change to `model` when shadowing is supported
    model2 =
        if model.saveState == Saved then
            { model & saveState: NoChanges }
        else
            model

    # Index into text contents
    index = calculateCursorIndex lines model.lineOffset model.cursor 0

    # Handle command
    when command is
        Nothing -> Task.ok (Step model2)
        Exit -> Task.ok (Done model2)
        UndoChanges ->
            model2
            |> updateUndoRedo Undo
            |> Step
            |> Task.ok

        RedoChanges ->
            model2
            |> updateUndoRedo Redo
            |> updateSaveState NotSaved
            |> Step
            |> Task.ok

        DeleteUnderCursor ->
            { added, table } = PieceTable.delete currentTable { index }

            { model2 &
                history: List.append model2.history table,
                future: [],
                # remove future as it is now stale
                added: added,
            }
            |> updateSaveState NotSaved
            |> Step
            |> Task.ok

        InsertCharacter str ->
            { added, table } = PieceTable.insert currentTable { values: [str], index }

            { model2 &
                history: List.append model2.history table,
                future: [],
                # remove future as it is now stale
                added: added,
            }
            |> \m ->
                if str == "\n" then
                    Core.updateCursor m Down
                else
                    Core.updateCursor m Right
            |> updateSaveState NotSaved
            |> Step
            |> Task.ok

        SaveChanges ->
            if model2.saveState == NoChanges then
                Task.ok (Step model2) # do nothing
            else
                # Convert graphemes to bytes
                graphemes =
                    currentTable
                    |> PieceTable.toList

                fileBytes =
                    graphemes
                    |> List.map Str.toUtf8
                    |> List.join

                # Write changes to file
                Path.writeBytes model.filePath fileBytes
                    |> Task.mapErr! UnableToSaveFile

                # Reset the editor state, cleanup history and rebuild buffers
                { model2 &
                    original: graphemes,
                    added: [],
                    history: [[Original { start: 0, len: List.len fileBytes }]],
                    future: [],
                    saveState: Saved,
                }
                |> Step
                |> Task.ok

        MoveCursor direction ->
            # We dont want the cursor to wrap around the screen,
            # instead move the lineOffset for the viewPort
            model3 =
                if model2.cursor.row == 0 && direction == Up then
                    { model2 & lineOffset: Num.subSaturated model2.lineOffset 1 }
                else if model2.cursor.row == (model2.screen.height - 2) && direction == Down then
                    { model2 & lineOffset: Num.addSaturated model2.lineOffset 1 }
                else if model2.cursor.col == 0 && direction == Left then
                    model2
                else if model2.cursor.col == model2.screen.width - 1 && direction == Right then
                    model2
                else
                    Core.updateCursor model2 direction

            Task.ok (Step model3)

updateSaveState : Model, [NoChanges, NotSaved, Saved] -> Model
updateSaveState = \m, saveState -> { m & saveState }

# undo moves table entries from history to future so they can be moved back if we redo
updateUndoRedo : Model, [Undo, Redo] -> Model
updateUndoRedo = \m, direction ->
    when direction is
        Undo ->
            when m.history is
                [] -> crash "unreachable, should always have some history"
                [_] -> m
                [.. as rest, latest] if List.len rest > 1 -> { m & history: rest, future: List.append m.future latest }
                [.. as rest, latest] ->
                    { m & history: rest, future: List.append m.future latest }
                    |> updateSaveState NoChanges

        Redo ->
            when m.future is
                [] -> m
                [.. as rest, latest] -> { m & history: List.append m.history latest, future: rest }

# Get the size of the terminal window
getTerminalSize : Task.Task Core.ScreenSize []_
getTerminalSize =

    # Move the cursor to bottom right corner of terminal
    [Cursor (Abs { row: 999, col: 999 }), Cursor (Position (Get))]
    |> List.map Control
    |> List.map Core.toStr
    |> Str.joinWith ""
    |> Stdout.write!

    # Read the cursor position
    Stdin.bytes {}
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
expect splitIntoLines ["f", "o", "o"] [] [] == [["f", "o", "o"]]
expect splitIntoLines ["f", "o", "o", "\r\n", "b", "a", "r"] [] [] == [["f", "o", "o"], ["b", "a", "r"]]

# We need to know the index of the cursor relative to the text content, the
# content has been broken into lines as CLRF and LF which we need to account for.
calculateCursorIndex : List (List Grapheme), U16, { row : U16, col : U16 }, U64 -> U64
calculateCursorIndex = \lines, lineOffset, cursor, acc ->
    if lineOffset > 0 then
        # add the length of each line that isn't displayed (before viewport)
        when lines is
            [] -> acc
            [first, .. as rest] -> calculateCursorIndex rest (lineOffset - 1) cursor (acc + List.len first + 1)
    else
        when lines is
            [] -> acc
            [first, .. as rest] if cursor.row > 0 -> calculateCursorIndex rest 0 { cursor & row: cursor.row - 1 } (acc + List.len first + 1)
            [first, ..] -> acc + (Num.min (List.len first) (Num.intCast cursor.col))
