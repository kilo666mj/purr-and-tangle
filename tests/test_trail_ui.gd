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
	for child in game.menu.get_child(0).get_children():
		if child is Button and child.text.begins_with("Yarn trail"):
			entry = child
	expect(entry != null, "Title menu offers Yarn trail")
	entry.pressed.emit()
	await process_frame
	var screen = game.trail
	expect(screen.visible and not game.board_view.visible and not game.menu.visible, "Yarn trail replaces the puzzle screen")
	var head: Vector2i = screen.trail.cells[0]
	await process_frame
	expect(screen.trail.cells[0] == head, "The kitten waits for a direction")
	await tap(KEY_UP)
	expect(screen.trail.moving and (screen.trail.heading == Vector2i.UP or screen.trail.turns.has(Vector2i.UP)), "Arrow keys steer the kitten")
	expect(game.session.paused and game.session.board.active.anchor == Vector2i(3, 0), "Steering does not reach the hidden puzzle")
	await tap(KEY_ESCAPE)
	expect(screen.mode == "pause" and screen.trail.paused, "Escape pauses Yarn trail")
	expect(root.gui_get_focus_owner() is Button, "Pause menu has controller focus")
	await tap(KEY_ESCAPE)
	expect(screen.mode.is_empty() and not screen.trail.paused, "Escape resumes Yarn trail")
	screen.trail.score = 30
	screen.trail.over = true
	await process_frame
	await process_frame
	var cat: TextureRect = screen.modal.find_child("OutcomeCat", true, false)
	expect(screen.mode == "lost" and cat != null and cat.texture == game.textures.cat_failure, "A tangle shows the result with the tangled cat")
	expect(game.trail_best == 30, "Best Yarn trail score is recorded")
	expect(screen.modal.position.y + screen.modal.size.y <= 900, "Result menu fits the viewport")
	screen.restart()
	expect(screen.mode.is_empty() and screen.trail.score == 0 and not screen.trail.over, "Try again starts a fresh run")
	game.return_to_title()
	await process_frame
	expect(not screen.visible and game.board_view.visible and game.menu_kind == "title", "Main menu returns to the title screen")
	game.queue_free()
	await process_frame
	print("Yarn trail UI: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
