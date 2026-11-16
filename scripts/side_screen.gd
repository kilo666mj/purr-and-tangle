extends "res://scripts/puzzle_art.gd"
## Shared shell for the small side games: header, steering, pause and result menus.
## A subclass sets the wording and grid below, supplies `game` (rules with start,
## turn, tick, score, moving, over, won and paused, plus an optional act) and
## draws its own board.

const TURNS := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT, "ui_up": Vector2i.UP, "soft": Vector2i.DOWN}

var host: Control
var game: RefCounted
var title := ""
var tagline := ""
var rules := ""
var lost_heading := ""
var won_heading := ""
var key := ""  # Set by the host; names this game's best score and screenshots.
var action := ""  # Label for the on-screen button of a game with an act().
var hint := "ARROWS / WASD / STICK  STEER"
var origin := Vector2.ZERO
var cell := 44.0
var grid := Vector2i.ZERO
var heard_score := 0
var mode := ""
var modal := PanelContainer.new()
var shade := ColorRect.new()
var run_seed := 0


func _ready() -> void:
	size = Vector2(1100, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_font.font_names = PackedStringArray(["DejaVu Serif", "Georgia"])
	var names := ["←", "↑", "↓", "→"]
	var turns := [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	for i in range(4):
		var direction: Vector2i = turns[i]
		var button: Button = host.make_button(names[i], Vector2(338 + i * 61, 786), Vector2(55, 44), func(): steer(direction), self)
		button.focus_mode = Control.FOCUS_NONE
	if not action.is_empty():
		var act: Button = host.make_button(action, Vector2(238, 786), Vector2(94, 44), func(): if mode.is_empty(): game.act(), self)
		act.focus_mode = Control.FOCUS_NONE
	var pause: Button = host.make_button("Pause · Esc / Start", Vector2(582, 786), Vector2(180, 44), toggle_pause, self)
	pause.focus_mode = Control.FOCUS_NONE
	shade.color = Color(0.08, 0.16, 0.13, 0.72)
	shade.size = size
	add_child(shade)
	modal.add_theme_stylebox_override("panel", panel_style(CREAM, 24, Color("b6c5ab"), 2))
	add_child(modal)


func open(seed_value: int) -> void:
	run_seed = seed_value
	restart()


func restart() -> void:
	# A fresh layout each attempt, still reproducible from the run seed.
	game.start(run_seed)
	run_seed += 1
	heard_score = 0
	resume()


func resume() -> void:
	mode = ""
	modal.hide()
	shade.hide()
	game.paused = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()
	queue_redraw()


func steer(direction: Vector2i) -> void:
	if mode.is_empty():
		game.turn(direction)


func show_menu(next_mode: String) -> void:
	mode = next_mode
	game.paused = true
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	modal.add_child(column)
	var heading := "Taking a catnap"
	var copy := "The kitten is holding still."
	var cta := "Keep playing"
	if mode != "pause":
		heading = won_heading if mode == "won" else lost_heading
		copy = "%s\nScore  %s  ·  Best  %s" % [summary(), format_score(game.score), format_score(host.bests[key])]
		cta = "Try again"
	host.make_label("PURR & TANGLE · " + title, 14, column)
	host.make_label(heading, 25, column)
	if mode != "pause":
		add_outcome_art(column, mode, 170.0)
	host.make_label(copy, 17, column)
	host.make_button(cta, Vector2.ZERO, Vector2(450, 46), resume if mode == "pause" else restart, column)
	if mode == "pause":
		host.make_button("Start over", Vector2.ZERO, Vector2(450, 40), restart, column)
	host.make_button("Main menu", Vector2.ZERO, Vector2(450, 40), host.return_to_title, column)
	host.make_label(rules, 14, column)
	modal.position = Vector2(307, 170)
	modal.size = Vector2(486, 0)
	modal.show()
	shade.show()
	focus_option.call_deferred()
	queue_redraw()


func focus_option() -> void:
	if modal.visible and modal.get_child_count() > 0:
		for child in modal.get_child(0).get_children():
			if child is Button:
				child.grab_focus()
				return


func toggle_pause() -> void:
	if mode == "pause":
		resume()
	elif mode.is_empty():
		show_menu("pause")


func pause_for_focus() -> void:
	if mode.is_empty():
		show_menu("pause")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause_game") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if mode == "pause" and event.is_action_pressed("ui_cancel") and not event.is_echo():
		resume()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("mute") and not event.is_echo():
		host.toggle_mute()
	if not mode.is_empty():
		return
	for turn in TURNS:
		if event.is_action_pressed(turn):
			game.turn(TURNS[turn])
	if not action.is_empty() and event.is_action_pressed("ui_accept") and not event.is_echo():
		game.act()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_W:
		game.turn(Vector2i.UP)
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or not mode.is_empty():
		return
	advance(minf(delta, 0.1))
	# Scoring can also happen on a key press, between frames.
	if game.score != heard_score:
		heard_score = game.score
		host.play_cat(520.0 + mini(game.score, 400), 0.2)
	if game.over:
		if not game.won:
			host.play_cat(110.0, 0.3, true)
		if game.score > host.bests[key]:
			host.bests[key] = game.score
			host.save_settings()
		show_menu("won" if game.won else "lost")
	queue_redraw()


func advance(delta: float) -> void:
	game.tick(delta)


func summary() -> String:
	return ""


func showcase() -> void:
	pass  # A subclass arranges a representative state for screenshots.


func draw_board() -> void:
	pass


func center(at: Vector2i) -> Vector2:
	return origin + (Vector2(at) + Vector2.ONE * 0.5) * cell


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CREAM)
	draw_circle(Vector2(40, 80), 240, Color("e8e9d7"))
	draw_circle(Vector2(1050, 880), 220, Color("dde4d3"))
	text_at("PURR & TANGLE", Vector2(152, 52), 21, INK, title_font)
	text_at(title, Vector2(152, 80), 14, MUTED)
	text_at("SCORE  " + format_score(game.score), Vector2(152, 112), 17, INK)
	text_at("BEST  " + format_score(maxi(host.bests[key], game.score)), Vector2(330, 112), 15, MUTED)
	text_at(summary().to_upper(), Vector2(700, 112), 15, MUTED)
	var rect := Rect2(origin, Vector2(grid) * cell)
	card(rect.grow(24), Color("b98f5d"), 22)
	card(rect.grow(7), Color("574d37"), 10)
	card(rect, Color("233e38"), 6)
	for y in range(grid.y):
		for x in range(grid.x):
			draw_circle(center(Vector2i(x, y)), 1, Color("486055"))
	# Pattern marks tell colors apart in the puzzle; here color is only decoration.
	show_patterns = false
	draw_board()
	if mode.is_empty() and not game.moving:
		card(Rect2(376, 742, 348, 34), CREAM, 10)
		text_at("Pick a direction to set off", Vector2(446, 765), 16, INK)
	text_at(hint, Vector2(152, 870), 12, MUTED)
	text_at(tagline, Vector2(680, 870), 16, MUTED, title_font)
