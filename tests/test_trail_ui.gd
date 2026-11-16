extends SceneTree

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.muted = true
	var entry: Button = null
	entry = game.menu.find_child("trail", true, false)
	expect(entry != null, "Game menu offers Yarn trail")
	entry.pressed.emit()
	await process_frame
	var screen = game.sides.trail
	expect(screen.visible and not game.board_view.visible and not game.menu.visible, "Yarn trail replaces the puzzle screen")
	var head: Vector2i = screen.game.cells[0]
	await process_frame
	expect(screen.game.cells[0] == head, "The kitten waits for a direction")
	await tap(KEY_UP)
	expect(screen.game.moving and (screen.game.heading == Vector2i.UP or screen.game.turns.has(Vector2i.UP)), "Arrow keys steer the kitten")
	expect(game.session.paused and game.session.board.active.anchor == Vector2i(3, 0), "Steering does not reach the hidden puzzle")
	await tap(KEY_ESCAPE)
	expect(screen.mode == "pause" and screen.game.paused, "Escape pauses Yarn trail")
	expect(root.gui_get_focus_owner() is Button, "Pause menu has controller focus")
	await tap(KEY_ESCAPE)
	expect(screen.mode.is_empty() and not screen.game.paused, "Escape resumes Yarn trail")
	screen.game.score = 30
	screen.game.over = true
	await process_frame
	await process_frame
	var cat: TextureRect = screen.modal.find_child("OutcomeCat", true, false)
	expect(screen.mode == "lost" and cat != null and cat.texture == game.textures.cat_failure, "A tangle shows the result with the tangled cat")
	expect(game.bests.trail == 30, "Best Yarn trail score is recorded")
	expect(screen.modal.position.y + screen.modal.size.y <= 900, "Result menu fits the viewport")
	screen.restart()
	expect(screen.mode.is_empty() and screen.game.score == 0 and not screen.game.over, "Try again starts a fresh run")
	game.return_to_title()
	await process_frame
	expect(not screen.visible and game.board_view.visible and game.menu_kind == "games", "Main menu returns to the game menu")
	entry = game.menu.find_child("pounce", true, false)
	entry.pressed.emit()
	await process_frame
	screen = game.sides.pounce
	expect(screen.visible and not game.sides.trail.visible, "Game menu opens Laser pounce")
	screen.game.dot = Vector2i(6, 3)
	await tap(KEY_RIGHT)
	expect(screen.game.cat == Vector2i(5, 3), "Arrow keys move the pouncing kitten")
	await tap(KEY_D)
	expect(screen.game.pounces == 1 and screen.game.score > 0, "Reaching the dot is a pounce")
	screen.game.misses = 2
	screen.game.time_left = 0.0
	await process_frame
	await process_frame
	expect(screen.mode == "lost" and screen.modal.find_child("OutcomeCat", true, false) != null, "Three escapes show the result")
	expect(game.bests.pounce == screen.game.score and game.bests.trail == 30, "Each side game keeps its own best score")
	game.return_to_title()
	await process_frame
	expect(not screen.visible and game.menu_kind == "games", "Laser pounce returns to the game menu")
	# Every side game opens from its card, runs, pauses and returns.
	for key in game.sides:
		game.menu.find_child(key, true, false).pressed.emit()
		await process_frame
		screen = game.sides[key]
		expect(game.side_game() == screen and screen.mode.is_empty(), "%s opens from its card" % key)
		await tap(KEY_RIGHT)
		await tap(KEY_ENTER)
		await process_frame
		expect(screen.game.moving and not screen.game.over, "%s responds to steering" % key)
		await tap(KEY_ESCAPE)
		expect(screen.mode == "pause" and screen.modal.position.y + screen.modal.size.y <= 900, "%s pauses with a menu that fits" % key)
		game.return_to_title()
		await process_frame
		expect(game.side_game() == null and game.menu_kind == "games", "%s returns to the game menu" % key)
	var dash = game.sides.dash
	dash.restart()
	for row in dash.game.lanes:
		dash.game.lanes[row].cells.clear()
	game.reduced_motion = false
	dash.advance(0.016)
	dash.game.turn(Vector2i.UP)
	dash.advance(0.016)
	expect(dash.shown_cat.y < 8.0 and dash.shown_cat.y > 7.0, "Kitchen dash eases the kitten between cells")
	var lane := {"dir": -1, "clock": 0.1, "interval": 0.4}
	expect(is_equal_approx(dash.glide(lane, 3), 3.25) and absf(dash.glide(lane, 3) - 3) <= 0.5, "Hazards glide within half a cell of their place")
	game.reduced_motion = true
	dash.advance(0.016)
	expect(dash.shown_cat == Vector2(dash.game.cat) and dash.glide(lane, 3) == 3.0, "Reduced motion snaps the kitten and hazards to their cells")
	game.reduced_motion = false
	game.sides.match.restart()
	game.sides.match.game.cursor = Vector2i(2, 1)
	game.sides.match.show()
	await tap(KEY_SPACE)
	expect(game.sides.match.game.picked == [8], "Kitten match flips the card under the cursor")
	game.return_to_title()
	game.queue_free()
	await process_frame
	print("Side games UI: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
