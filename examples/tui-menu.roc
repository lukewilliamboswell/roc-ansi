app [main!] {
    # cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.18.0/0APbwVN1_p1mJ96tXjaoiUCr8NBGamr8G8Ac_DrXR-o.tar.br",
    cli: platform "../../basic-cli/platform/main.roc",
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
    prev_draw : Utc.Utc,
    curr_draw : Utc.Utc,
    things : List Str,
    inputs : List ANSI.Input,
    debug : Bool,
    state : [HomePage, ConfirmPage Str, DoSomething Str, UserExited],
}

init : Model
init = {
    cursor: { row: 3, col: 3 },
    screen: { width: 0, height: 0 },
    prev_draw: Utc.from_millis_since_epoch(0),
    curr_draw: Utc.from_millis_since_epoch(0),
    things: ["Foo", "Bar", "Baz"],
    inputs: List.with_capacity(1000),
    debug: Bool.true,
    state: HomePage,
}

render : Model -> List ANSI.DrawFn
render = \model ->
    # PRESS 'd' to toggle debug screen
    debug = if model.debug then debug_screen(model) else []

    when model.state is
        ConfirmPage(_) ->
            List.join(
                [
                    confirm_screen(model),
                    debug,
                ],
            )

        _ ->
            List.join(
                [
                    home_screen(model),
                    debug,
                ],
            )

main! = \_ ->

    # TUI Dashboard
    Tty.enable_raw_mode!({})
    model = run_ui_loop!(init)?
    # Restore terminal
    Stdout.write!(ANSI.to_str(Reset))?
    Tty.disable_raw_mode!({})

    # EXIT or RUN selected solution
    when model.state is
        DoSomething(selected) ->
            Stdout.line!("Doing something with $(selected)... now exiting...")

        _ ->
            Stdout.line!("Exiting...")

run_ui_loop! : Model => Result Model []_
run_ui_loop! = \prev_model ->

    # Get the time of this draw
    now = Utc.now!({})

    # Update screen size (in case it was resized since the last draw)
    terminal_size = get_terminal_size!({})?

    # Update the model with screen size and time of this draw
    model = { prev_model & screen: terminal_size, prev_draw: prev_model.curr_draw, curr_draw: now }

    # Draw the screen
    draw_fns = render(model)
    ANSI.draw_screen(model, draw_fns) |> Stdout.write! |> try

    # Get user input
    input = Stdin.bytes!({}) |> Result.map(ANSI.parse_raw_stdin) |> try

    # Parse user input into a command
    command =
        when (input, model.state) is
            (Arrow(Up), _) -> MoveCursor(Up)
            (Arrow(Down), _) -> MoveCursor(Down)
            (Arrow(Left), _) -> MoveCursor(Left)
            (Arrow(Right), _) -> MoveCursor(Right)
            (Lower(D), _) -> ToggleDebug
            (Action(Enter), HomePage) -> UserToggledScreen
            (Action(Enter), ConfirmPage(s)) -> UserWantToDoSomthing(s)
            (Action(Escape), ConfirmPage(_)) -> UserToggledScreen
            (Action(Escape), _) -> Exit
            (Ctrl(C), _) -> Exit
            (Unsupported(_), _) -> Nothing
            (_, _) -> Nothing

    # Update model so we can keep a history of user input
    model_with_input = { model & inputs: List.append(model.inputs, input) }

    # Action command
    when command is
        Exit -> Ok({ model_with_input & state: UserExited })
        Nothing -> run_ui_loop!(model_with_input)
        ToggleDebug -> run_ui_loop!({ model_with_input & debug: !model_with_input.debug })
        MoveCursor(direction) -> run_ui_loop!(ANSI.update_cursor(model_with_input, direction))
        UserWantToDoSomthing(s) -> Ok({ model_with_input & state: DoSomething(s) })
        UserToggledScreen ->
            when model_with_input.state is
                HomePage ->
                    result = get_selected(model_with_input)

                    when result is
                        Ok(selected) -> run_ui_loop!({ model_with_input & state: ConfirmPage(selected) })
                        Err(NothingSelected) -> run_ui_loop!(model_with_input)

                _ -> run_ui_loop!({ model_with_input & state: HomePage })

map_selected : Model -> List { selected : Bool, s : Str, row : U16 }
map_selected = \model ->
    List.map_with_index(
        model.things,
        \s, idx ->
            row = 3 + (Num.to_u16(idx))
            { selected: model.cursor.row == row, s, row },
    )

get_selected : Model -> Result Str [NothingSelected]
get_selected = \model ->
    map_selected(model)
    |> List.keep_oks(\{ selected, s } -> if selected then Ok(s) else Err({}))
    |> List.first
    |> Result.map_err(\_ -> NothingSelected)

get_terminal_size! : {} => Result ANSI.ScreenSize _
get_terminal_size! = \{} ->

    # Move the cursor to bottom right corner of terminal
    cmd = [Cursor(Abs({ row: 999, col: 999 })), Cursor(Position(Get))] |> List.map(Control) |> List.map(ANSI.to_str) |> Str.join_with("")
    Stdout.write!(cmd)?

    # Read the cursor position
    Stdin.bytes!({})
    |> Result.map(ANSI.parse_cursor)
    |> Result.map(\{ row, col } -> { width: col, height: row })

home_screen : Model -> List ANSI.DrawFn
home_screen = \model ->
    [
        [
            ANSI.draw_cursor({ bg: Standard(Green) }),
            ANSI.draw_text(" Choose your Thing, Toggle debug overlay with 'd'", { r: 1, c: 1, fg: Standard(Green) }),
            ANSI.draw_text("RUN", { r: 2, c: 11, fg: Standard(Blue) }),
            ANSI.draw_text("QUIT", { r: 2, c: 26, fg: Standard(Red) }),
            ANSI.draw_text(" ENTER TO RUN, ESCAPE TO QUIT", { r: 2, c: 1, fg: Standard(White) }),
            ANSI.draw_box({ r: 0, c: 0, w: model.screen.width, h: model.screen.height }),
        ],
        model
        |> map_selected
        |> List.map(
            \{ selected, s, row } ->
                if selected then
                    ANSI.draw_text(" > $(s)", { r: row, c: 2, fg: Standard(Green) })
                else
                    ANSI.draw_text(" - $(s)", { r: row, c: 2, fg: Standard(Black) }),
        ),
    ]
    |> List.join

confirm_screen : Model -> List ANSI.DrawFn
confirm_screen = \state -> [
    ANSI.draw_cursor({ bg: Standard(Green) }),
    ANSI.draw_text(" Would you like to do something?", { r: 1, c: 1, fg: Standard(Yellow) }),
    ANSI.draw_text("CONFIRM", { r: 2, c: 11, fg: Standard(Blue) }),
    ANSI.draw_text("RETURN", { r: 2, c: 30, fg: Standard(Red) }),
    ANSI.draw_text(" ENTER TO CONFIRM, ESCAPE TO RETURN", { r: 2, c: 1, fg: Standard(White) }),
    ANSI.draw_text(" count: TBC", { r: 3, c: 1 }),
    ANSI.draw_text(" speed: TBC", { r: 4, c: 1 }),
    ANSI.draw_text(" size: TBC", { r: 5, c: 1 }),
    ANSI.draw_box({ r: 0, c: 0, w: state.screen.width, h: state.screen.height }),
]

debug_screen : Model -> List ANSI.DrawFn
debug_screen = \state ->
    cursor_str = "CURSOR R$(Num.to_str(state.cursor.row)), C$(Num.to_str(state.cursor.col))"
    screen_str = "SCREEN H$(Num.to_str(state.screen.height)), W$(Num.to_str(state.screen.width))"
    input_delta_str = "DELTA $(Num.to_str(Utc.delta_as_millis(state.prev_draw, state.curr_draw))) millis"
    last_input =
        state.inputs
        |> List.last
        |> Result.map(ANSI.input_to_str)
        |> Result.map(\str -> "INPUT $(str)")
        |> Result.with_default("NO INPUT YET")

    [
        ANSI.draw_text(last_input, { r: state.screen.height - 5, c: 1, fg: Standard(Magenta) }),
        ANSI.draw_text(input_delta_str, { r: state.screen.height - 4, c: 1, fg: Standard(Magenta) }),
        ANSI.draw_text(cursor_str, { r: state.screen.height - 3, c: 1, fg: Standard(Magenta) }),
        ANSI.draw_text(screen_str, { r: state.screen.height - 2, c: 1, fg: Standard(Magenta) }),
        ANSI.draw_v_line({ r: 1, c: state.screen.width // 2, len: state.screen.height, fg: Standard(White) }),
        ANSI.draw_h_line({ c: 1, r: state.screen.height // 2, len: state.screen.width, fg: Standard(White) }),
    ]
