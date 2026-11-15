extends SceneTree

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func joy(device: int, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap(device: int, index: int) -> void:
	joy(device, index, true)
	await process_frame
	await process_frame
	joy(device, index, false)
	await process_frame
	await process_frame


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var saved_difficulty: int = game.difficulty
	await tap(2, JOY_BUTTON_DPAD_DOWN)
	expect(root.gui_get_focus_owner().text == "Local two-player versus", "Versus is reachable from the title by controller")
	await tap(2, JOY_BUTTON_A)
	var screen = game.versus
	expect(screen.visible and screen.mode == "lobby" and not game.board_view.visible, "Versus opens lobby and hides solo controls")
	expect(not screen.inputs.ready(), "Players must join explicitly")
	screen.begin_round()
	expect(screen.mode == "lobby", "Cannot start without both players")
	await tap(2, JOY_BUTTON_A)
	expect(screen.inputs.devices == [2, screen.Inputs.EMPTY], "First physical controller joins player one")
	await tap(7, JOY_BUTTON_A)
	expect(screen.inputs.devices == [2, 7], "Second physical controller joins player two")
	expect(screen.mode == "lobby", "Joining press and release cannot also start the race")
	expect(root.gui_get_focus_owner().text == "Start the race", "Ready lobby focuses start")
	screen.cycle_difficulty()
	await process_frame
	await process_frame
	var selected_difficulty: int = game.difficulty
	expect(screen.match_state.difficulty == selected_difficulty and screen.inputs.devices == [2, 7], "Difficulty can change without losing joined controllers")
	expect(screen.match_state.players[0].board.cells == screen.match_state.players[1].board.cells, "Lobby difficulty resets both boards equally")
	game.difficulty = -1
	game.load_settings()
	expect(game.difficulty == selected_difficulty, "Difficulty selection persists in local settings")
	await tap(2, JOY_BUTTON_START)
	expect(screen.mode.is_empty() and screen.match_state.countdown > 2.0, "Start begins a shared countdown")
	expect(screen.match_state.players[0].board.active.anchor.y == 0 and screen.match_state.players[1].board.active.anchor.y == 0, "Both baskets wait for countdown")
	await tap(7, JOY_BUTTON_START)
	var frozen_countdown: float = screen.match_state.countdown
	screen.match_state.tick(10)
	expect(screen.mode == "pause" and screen.match_state.countdown == frozen_countdown, "Either player can pause the countdown")
	await tap(2, JOY_BUTTON_B)
	expect(screen.mode.is_empty(), "Assigned controller B resumes")
	screen.match_state.countdown = 0
	await tap(2, JOY_BUTTON_DPAD_LEFT)
	expect(screen.match_state.players[0].board.active.anchor.x == 2 and screen.match_state.players[1].board.active.anchor.x == 3, "Real player one events move only left basket")
	await tap(7, JOY_BUTTON_DPAD_RIGHT)
	expect(screen.match_state.players[0].board.active.anchor.x == 2 and screen.match_state.players[1].board.active.anchor.x == 4, "Real player two events move only right basket")
	await tap(9, JOY_BUTTON_X)
	await tap(9, JOY_BUTTON_START)
	expect(screen.mode.is_empty() and not screen.match_state.players[0].board.active.is_empty() and not screen.match_state.players[1].board.active.is_empty(), "Unassigned controller cannot play or pause")
	await tap(2, JOY_BUTTON_A)
	expect(screen.match_state.players[0].board.active.offset == Vector2i.DOWN and screen.match_state.players[1].board.active.offset == Vector2i.RIGHT, "Rotation is isolated")
	game.controller_changed(9, false)
	expect(screen.mode.is_empty(), "Unassigned controller disconnect does not interrupt match")
	joy(2, JOY_BUTTON_DPAD_LEFT, true)
	await process_frame
	game.controller_changed(2, false)
	await process_frame
	expect(screen.mode == "pause" and screen.match_state.players[0].paused and screen.match_state.players[1].paused, "Assigned disconnect freezes both boards")
	expect(screen.inputs.devices == [screen.Inputs.EMPTY, 7], "Disconnect keeps the other player's assignment")
	screen.begin_round()
	expect(screen.mode == "pause", "Cannot resume with a missing player")
	await tap(5, JOY_BUTTON_A)
	expect(screen.inputs.devices == [5, 7] and screen.mode == "pause", "Replacement joins without accidentally resuming")
	await tap(7, JOY_BUTTON_START)
	var stopped_x: int = screen.match_state.players[0].board.active.anchor.x
	screen._process(0.1)
	expect(screen.mode.is_empty() and screen.match_state.players[0].board.active.anchor.x == stopped_x, "Resume clears disconnected controller's held movement")
	joy(2, JOY_BUTTON_DPAD_LEFT, false)
	await tap(7, JOY_BUTTON_X)
	expect(screen.match_state.players[1].board.pair_serial == 1 and screen.match_state.players[0].board.pair_serial == 0, "Hard drop locks only the assigned board")
	screen.pause_for_focus()
	expect(screen.mode == "pause", "Losing window focus pauses both baskets")
	screen.begin_round()
	screen.match_state.players[0].board.phase = screen.Board.Phase.WON
	await process_frame
	await process_frame
	expect(screen.mode == "result" and screen.match_state.wins == [1, 0], "Winner screen records one win")
	await tap(5, JOY_BUTTON_A)
	expect(screen.mode.is_empty() and screen.match_state.round_number == 2 and screen.match_state.wins == [1, 0], "Controller can rematch with wins preserved")
	expect(screen.match_state.countdown > 2 and screen.inputs.devices == [5, 7], "Rematch retains controllers and restores countdown")
	expect(screen.match_state.players[0].board.cells == screen.match_state.players[1].board.cells, "Rematch remains fair")
	expect(screen.match_state.difficulty == selected_difficulty, "Rematch retains selected difficulty")
	game.return_to_title()
	await process_frame
	expect(not screen.visible and game.menu_kind == "title" and game.board_view.visible, "Main menu restores single-player presentation")
	game.start_versus()
	key(KEY_F1, true)
	key(KEY_F1, false)
	key(KEY_F2, true)
	key(KEY_F2, false)
	await process_frame
	await process_frame
	expect(screen.inputs.devices == [screen.Inputs.KEYBOARD_ONE, screen.Inputs.KEYBOARD_TWO], "F1/F2 enable shared keyboard in lobby")
	key(KEY_ENTER, true)
	await process_frame
	key(KEY_ENTER, false)
	await process_frame
	expect(screen.mode.is_empty(), "Keyboard can start race from menu")
	screen.match_state.countdown = 0
	key(KEY_A, true)
	key(KEY_RIGHT, true)
	await process_frame
	await process_frame
	key(KEY_A, false)
	key(KEY_RIGHT, false)
	expect(screen.match_state.players[0].board.active.anchor.x == 2 and screen.match_state.players[1].board.active.anchor.x == 4, "Shared keyboard controls are independent in the actual scene")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await process_frame
	expect(screen.mode == "pause", "Escape pauses shared-keyboard play")
	var controls: Array = screen.modal.get_child(0).get_children()
	for child in controls:
		if child is Control:
			expect(child.position.y + child.size.y <= screen.modal.size.y, "Pause menu fits its modal")
	expect(screen.modal.position.y + screen.modal.size.y <= 900, "Pause menu stays within the logical viewport")
	game.return_to_title()
	game.start_game()
	expect(game.menu_kind.is_empty() and not game.session.paused and not screen.visible, "Single-player still works after versus")
	expect(game.session.difficulty == selected_difficulty, "Single-player uses the saved difficulty")
	game.session.board.phase = game.Board.Phase.WON
	await process_frame
	await process_frame
	game.menu_primary()
	expect(game.session.difficulty == selected_difficulty and game.session.board.level == 2, "Solo level progression keeps its difficulty")
	game.difficulty = saved_difficulty
	game.save_settings()
	game.sound.stop()
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.10).timeout
	print("Versus UI/controllers: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
