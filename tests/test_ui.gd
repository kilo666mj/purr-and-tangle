extends SceneTree

var failures := 0
var checks := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func joy(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	expect(game.menu_kind == "title", "Start screen is visible")
	expect(root.gui_get_focus_owner() is Button, "Start menu has controller focus")
	joy(JOY_BUTTON_A, true)
	await process_frame
	joy(JOY_BUTTON_A, false)
	await process_frame
	await process_frame
	expect(game.menu_kind.is_empty() and not game.session.paused, "Starting enters playable state")
	var x: int = game.session.board.active.anchor.x
	joy(JOY_BUTTON_DPAD_LEFT, true)
	await process_frame
	await process_frame
	joy(JOY_BUTTON_DPAD_LEFT, false)
	expect(game.session.board.active.anchor.x == x - 1, "Controller D-pad moves the falling pair")
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.8
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	expect(game.session.board.active.anchor.x == x, "Controller left stick moves the pair with a dead zone")
	joy(JOY_BUTTON_A, true)
	await process_frame
	await process_frame
	joy(JOY_BUTTON_A, false)
	expect(game.session.board.active.offset == Vector2i.DOWN, "Controller A rotates clockwise")
	joy(JOY_BUTTON_B, true)
	await process_frame
	await process_frame
	joy(JOY_BUTTON_B, false)
	expect(game.session.board.active.offset == Vector2i.RIGHT, "Controller B rotates counterclockwise")
	joy(JOY_BUTTON_START, true)
	await process_frame
	joy(JOY_BUTTON_START, false)
	expect(game.session.paused and game.menu_kind == "pause", "Controller Start pauses")
	await process_frame
	var selected: Control = root.gui_get_focus_owner()
	expect(selected is Button and selected.text == "Keep playing", "Pause menu focuses Resume")
	joy(JOY_BUTTON_DPAD_DOWN, true)
	await process_frame
	joy(JOY_BUTTON_DPAD_DOWN, false)
	expect(root.gui_get_focus_owner() != selected, "Controller navigates pause menu")
	var board_before = game.session.board.cells.duplicate(true)
	game.session.tick(10.0, true)
	expect(game.session.board.cells == board_before, "Pause menu keeps the board frozen")
	game.controller_changed(0, false)
	expect(game.session.paused, "Controller disconnect keeps game paused")
	game.start_game()
	game.controller_changed(0, false)
	expect(game.menu_kind == "pause", "Controller disconnect during play opens pause menu")
	game.start_game()
	joy(JOY_BUTTON_X, true)
	await process_frame
	joy(JOY_BUTTON_X, false)
	expect(game.session.board.active.is_empty(), "Controller X hard-drops and locks the pair")
	expect(game.companion.reaction == "drop", "Companion reacts to a controller hard drop")
	game.toggle_pause()
	var companion_time: float = game.companion.elapsed
	await process_frame
	expect(game.companion.elapsed == companion_time, "Pause freezes companion animation")
	game.resume_game()
	game.session.board.phase = game.Board.Phase.WON
	await process_frame
	expect(game.menu_kind == "won", "Winning shows the next-basket menu")
	await process_frame
	var win_cat: TextureRect = game.menu.find_child("OutcomeCat", true, false)
	expect(win_cat != null and win_cat.texture == game.textures.cat_won, "Win menu displays the rescued kittens")
	expect(game.menu.position.y + game.menu.size.y <= 900, "Win art and controls fit the viewport")
	expect(root.gui_get_focus_owner().text == "Next basket", "Outcome art preserves controller focus")
	game.menu_primary()
	expect(game.session.board.level == 2 and game.menu_kind.is_empty(), "Next basket continues the run")
	game.session.board.phase = game.Board.Phase.LOST
	await process_frame
	expect(game.menu_kind == "lost", "Blocked board shows game over")
	await process_frame
	var loss_cat: TextureRect = game.menu.find_child("OutcomeCat", true, false)
	expect(loss_cat != null and loss_cat.texture == game.textures.cat_failure, "Loss menu displays the tangled cat")
	expect(game.menu.position.y + game.menu.size.y <= 900, "Loss art and controls fit the viewport")
	game.menu_primary()
	expect(game.session.board.level == 1 and game.session.board.score == 0, "Restart resets run state")
	expect(game.mute_button.position.y + game.mute_button.size.y <= game.motion_button.position.y, "Settings buttons do not overlap")
	game.muted = false
	game.play_cat(600.0, 0.5)
	expect(game.sound.stream.data.size() == 22050, "Meow fills its sample buffer")
	game.play_cat(110.0, 0.5, true)
	expect(game.sound.stream.data.size() == 22050, "Purr fills its sample buffer")
	game.sound.stop()
	game.queue_free()
	await process_frame
	await process_frame
	# Let the audio thread release the final tone before this short headless run exits.
	await create_timer(0.10).timeout
	print("UI/controller: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
