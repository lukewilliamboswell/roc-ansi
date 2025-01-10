app [main!] {
    # cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.18.0/0APbwVN1_p1mJ96tXjaoiUCr8NBGamr8G8Ac_DrXR-o.tar.br",
    cli: platform "../../basic-cli/platform/main.roc",
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
import ansi.ANSI
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
    |> Str.to_utf8
    |> List.keep_oks(\char -> Str.from_utf8([char]))
    |> Ok

# We are working with a single visible "character", let's use an alias to help with type checking
Grapheme : Str

# Keep track of application state between update->render loop
Model : {
    # Keep track of screen size to handle resizes
    screen : ANSI.ScreenSize,

    # Keep track of the cursor position
    cursor : ANSI.CursorPosition,

    # Offset the viewPort from the start of file
    line_offset : U16,

    # Keep track of file saves
    save_state : [NoChanges, NotSaved, Saved],

    # Path of the file we are editing
    file_path : Path.Path,

    # Buffers for the original file contents, and content appended while editing
    original : List Grapheme,
    added : List Grapheme,

    # Two tables to record undo/redo history of edits
    history : List (List PieceTable.Entry),
    future : List (List PieceTable.Entry),
}

# Initilise the application state
init : List Grapheme, Path.Path -> Model
init = \original, file_path ->

    # initialise with the contents of the text file we want to edit
    first_piece_table : List PieceTable.Entry
    first_piece_table = [Original({ start: 0, len: List.len(original) })]

    {
        cursor: { row: 3, col: 3 },
        screen: { width: 0, height: 0 },
        line_offset: 0,
        save_state: NoChanges,
        file_path,
        original,
        added: List.with_capacity(1000),
        history: List.with_capacity(1000) |> List.append(first_piece_table),
        future: [],
    }

# Render the screen after each update
render : Model, List (List Grapheme) -> List ANSI.DrawFn
render = \state, lines ->

    changes_count = List.len(state.history) - 1 |> Num.to_str
    redo_msg = if List.len(state.future) > 0 then ", CTRL-Y to Redo changes" else ""
    saved_msg =
        when state.save_state is
            NoChanges -> "Nothing to save$(redo_msg)"
            NotSaved -> "CTRL-S to save $(changes_count) changes, CTRL-Z to Undo changes$(redo_msg)"
            Saved -> "Changes saved to $(Path.display(state.file_path))"

    # Draw functions
    [
        ANSI.draw_text("ESC to EXIT: $(saved_msg)", { r: state.screen.height - 1, c: 0, fg: Standard(Magenta) }),
        ANSI.draw_cursor({ bg: Standard(Green) }),
        draw_view_port(
            {
                lines,
                line_offset: state.line_offset,
                width: state.screen.width,
                height: state.screen.height - 1,
                position: { row: 0, col: 0 },
            },
        ),
    ]

# Draw lines into a viewport on the screen
draw_view_port :
    {
        lines : List (List Grapheme),
        line_offset : U16,
        width : U16,
        height : U16,
        position : ANSI.CursorPosition,
    }
    -> ANSI.DrawFn
draw_view_port = \{ lines, line_offset, width, height, position } ->
    \_, { row, col } ->
        if row < position.row || row >= (position.row + height) || col < position.col || col >= (position.col + width) then
            Err({}) # only draw pixels within this viewport
        else
            line_index : U64
            line_index = Num.int_cast((row - position.col + (Num.int_cast(line_offset))))

            char_index : U64
            char_index = Num.int_cast((col - position.col))

            when List.get(lines, line_index) is
                Err(OutOfBounds) ->
                    # if the viewport has lines that are outside the buffer, just render blank spaces
                    Ok({ char: " ", fg: Default, bg: Default, styles: [] })

                Ok(line) ->
                    if char_index == List.len(line) then
                        # render "¶" so users can see line breaks
                        Ok({ char: "¶", fg: Standard(Cyan), bg: Default, styles: [] })
                    else
                        char : Grapheme
                        char = List.get(line, char_index) |> Result.with_default (" ")
                        Ok({ char, fg: Default, bg: Default, styles: [] })

main! = \args ->

    # Read path of file to edit from argument
    path = read_arg_file_path(args)?

    # Check if the file exists
    file_exists =
        Path.is_file!(path)
        |> Result.on_err!(
            \err ->
                if err == PathDoesNotExist then
                    Ok(Bool.false)
                else
                    Err(UnableToCheckFile),
        )
        |> try

    # Read the file
    original = get_file_contents!({ file_exists, path })?

    # Loop UI command->update->render
    Tty.enable_raw_mode!({})
    model = run_ui_loop!(init(original, path))?

    # Restore terminal
    Stdout.write!(ANSI.to_str(Reset))?
    Tty.disable_raw_mode!({})
    Stdout.write!(ANSI.to_str(Control(Cursor(Abs({ row: 0, col: 0 })))))?

    Stdout.line!("Finished editing $(Path.display(model.file_path))")

# A task that will read the file contents, split into extended grapheme clusters
get_file_contents! : { file_exists : Bool, path : Path.Path } => Result (List Grapheme) _
get_file_contents! = \{ file_exists, path } ->
    if file_exists then
        Path.read_utf8!(path)
        |> Result.map_err(UnableToOpenFile)
        |> Result.try(
            \file_contents ->
                file_contents
                |> split
                |> Result.map_err(UnableToSplitIntoGraphemes),
        )
    else
        Ok([]) # file doesn't exist, we will write to it when we save

# Get the file path from the first argument
read_arg_file_path : List Arg.Arg -> Result Path.Path _
read_arg_file_path = \args ->
    when args is
        [_, path_arg, ..] ->
            path_arg
            |> Arg.display
            |> Path.from_str
            |> Ok

        _ -> Err(FailedToReadArgs ("expected file argument e.g. 'roc run tui-editor.roc -- file.txt'"))

# UI Loop command->update->render
run_ui_loop! : Model => Result Model []_
run_ui_loop! = \prev_model ->

    # Update screen size (in case it was resized since the last draw)
    terminal_size = get_terminal_size!({})?

    # Update the model with screen size and time of this draw
    model = { prev_model & screen: terminal_size }

    # Use the current selected piece table
    current_table : PieceTable.PieceTable Grapheme
    current_table = {
        original: model.original,
        added: model.added,
        table: List.last(model.history) |> Result.with_default([]),
    }

    # Fuse into a single buffer of Graphemes
    chars : List Grapheme
    chars = PieceTable.to_list(current_table)

    # Split into lines on line breaks
    lines : List (List Grapheme)
    lines = split_into_lines(chars, [], [])

    # Draw the screen
    draw_fns = render(model, lines)
    ANSI.draw_screen(model, draw_fns) |> Stdout.write! |> try

    # Get user input
    input = Result.map(Stdin.bytes!({}), ANSI.parse_raw_stdin)?

    # Parse input into a command
    command =
        when input is
            Arrow(Up) -> MoveCursor(Up)
            Arrow(Down) -> MoveCursor(Down)
            Arrow(Left) -> MoveCursor(Left)
            Arrow(Right) -> MoveCursor(Right)
            Action(Escape) -> Exit
            Action(Delete) -> DeleteUnderCursor
            Action(Space) -> InsertCharacter(" ")
            Action(Enter) -> InsertCharacter("\n")
            Symbol(symbol) -> InsertCharacter(ANSI.symbol_to_str(symbol))
            Upper(key) -> InsertCharacter(ANSI.upper_to_str(key))
            Lower(key) -> InsertCharacter(ANSI.lower_to_str(key))
            Ctrl(C) -> Exit
            Ctrl(S) -> SaveChanges
            Ctrl(Y) -> RedoChanges
            Ctrl(Z) -> UndoChanges
            Unsupported(key) -> crash(Inspect.to_str(key))
            _ -> Nothing

    # TODO change to `model` when shadowing is supported
    model2 =
        if model.save_state == Saved then
            { model & save_state: NoChanges }
        else
            model

    # Index into text contents
    index = calculate_cursor_index(lines, model.line_offset, model.cursor, 0)

    # Handle command
    when command is
        Exit ->
            Ok(model2)

        Nothing ->
            run_ui_loop!(model2)

        UndoChanges ->
            model2
            |> update_undo_redo(Undo)
            |> run_ui_loop!

        RedoChanges ->
            model2
            |> update_undo_redo(Redo)
            |> update_save_state(NotSaved)
            |> run_ui_loop!

        DeleteUnderCursor ->
            { added, table } = PieceTable.delete(current_table, { index })

            { model2 &
                history: List.append(model2.history, table),
                future: [],
                # remove future as it is now stale
                added: added,
            }
            |> update_save_state(NotSaved)
            |> run_ui_loop!

        InsertCharacter(str) ->
            { added, table } = PieceTable.insert(current_table, { values: [str], index })

            { model2 &
                history: List.append(model2.history, table),
                future: [],
                # remove future as it is now stale
                added: added,
            }
            |> \m ->
                if str == "\n" then
                    ANSI.update_cursor(m, Down)
                else
                    ANSI.update_cursor(m, Right)
            |> update_save_state(NotSaved)
            |> run_ui_loop!

        SaveChanges ->
            if model2.save_state == NoChanges then
                run_ui_loop!(model2) # do nothing
            else
                # Convert graphemes to bytes
                graphemes =
                    current_table
                    |> PieceTable.to_list

                file_bytes =
                    graphemes
                    |> List.map(Str.to_utf8)
                    |> List.join

                # Write changes to file
                Path.write_bytes!(file_bytes, model.file_path)
                |> Result.map_err(UnableToSaveFile)
                |> try

                # Reset the editor state, cleanup history and rebuild buffers
                { model2 &
                    original: graphemes,
                    added: [],
                    history: [[Original({ start: 0, len: List.len(file_bytes) })]],
                    future: [],
                    save_state: Saved,
                }
                |> run_ui_loop!

        MoveCursor(direction) ->
            # We dont want the cursor to wrap around the screen,
            # instead move the lineOffset for the viewPort
            model3 =
                if model2.cursor.row == 0 && direction == Up then
                    { model2 & line_offset: Num.sub_saturated(model2.line_offset, 1) }
                else if model2.cursor.row == (model2.screen.height - 2) && direction == Down then
                    { model2 & line_offset: Num.add_saturated(model2.line_offset, 1) }
                else if model2.cursor.col == 0 && direction == Left then
                    model2
                else if model2.cursor.col == model2.screen.width - 1 && direction == Right then
                    model2
                else
                    ANSI.update_cursor(model2, direction)

            run_ui_loop!(model3)

update_save_state : Model, [NoChanges, NotSaved, Saved] -> Model
update_save_state = \m, save_state -> { m & save_state }

# undo moves table entries from history to future so they can be moved back if we redo
update_undo_redo : Model, [Undo, Redo] -> Model
update_undo_redo = \m, direction ->
    when direction is
        Undo ->
            when m.history is
                [] -> crash("unreachable, should always have some history")
                [_] -> m
                [.. as rest, latest] if List.len(rest) > 1 -> { m & history: rest, future: List.append(m.future, latest) }
                [.. as rest, latest] ->
                    { m & history: rest, future: List.append(m.future, latest) }
                    |> update_save_state(NoChanges)

        Redo ->
            when m.future is
                [] -> m
                [.. as rest, latest] -> { m & history: List.append(m.history, latest), future: rest }

# Get the size of the terminal window
get_terminal_size! : {} => Result ANSI.ScreenSize []_
get_terminal_size! = \{} ->

    # Move the cursor to bottom right corner of terminal
    [Cursor(Abs({ row: 999, col: 999 })), Cursor(Position(Get))]
    |> List.map(Control)
    |> List.map(ANSI.to_str)
    |> Str.join_with("")
    |> Stdout.write!
    |> try

    # Read the cursor position
    Stdin.bytes!({})
    |> Result.map(ANSI.parse_cursor)
    |> Result.map(\{ row, col } -> { width: col, height: row })

# Helper to split grepheme's on line breaks
split_into_lines : List Grapheme, List Grapheme, List (List Grapheme) -> List (List Grapheme)
split_into_lines = \chars, line, lines ->
    when chars is
        [] if List.is_empty(line) -> lines
        [] -> List.append(lines, line)
        [a, .. as rest] if a == "\r\n" || a == "\n" -> split_into_lines(rest, [], List.append(lines, line))
        [a, .. as rest] -> split_into_lines(rest, List.append(line, a), lines)

expect split_into_lines([], [], []) == []
expect split_into_lines(["f", "o", "o"], [], []) == [["f", "o", "o"]]
expect split_into_lines(["f", "o", "o", "\r\n", "b", "a", "r"], [], []) == [["f", "o", "o"], ["b", "a", "r"]]

# We need to know the index of the cursor relative to the text content, the
# content has been broken into lines as CLRF and LF which we need to account for.
calculate_cursor_index : List (List Grapheme), U16, { row : U16, col : U16 }, U64 -> U64
calculate_cursor_index = \lines, line_offset, cursor, acc ->
    if line_offset > 0 then
        # add the length of each line that isn't displayed (before viewport)
        when lines is
            [] -> acc
            [first, .. as rest] -> calculate_cursor_index(rest, (line_offset - 1), cursor, (acc + List.len(first) + 1))
    else
        when lines is
            [] -> acc
            [first, .. as rest] if cursor.row > 0 -> calculate_cursor_index(rest, 0, { cursor & row: cursor.row - 1 }, (acc + List.len(first) + 1))
            [first, ..] -> acc + (Num.min(List.len(first), Num.int_cast(cursor.col)))
