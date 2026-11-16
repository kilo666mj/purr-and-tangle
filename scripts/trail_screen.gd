extends "res://scripts/puzzle_art.gd"
## Yarn trail presentation: one basket, one kitten, one ever-longer strand.

const Trail = preload("res://scripts/trail.gd")
const ORIGIN := Vector2(176, 150)
const CELL := 44.0
const TURNS := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT, "ui_up": Vector2i.UP, "soft": Vector2i.DOWN}

var host: Control
var trail := Trail.new()
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
	trail.start(run_seed)
	run_seed += 1
	resume()


func resume() -> void:
	mode = ""
	modal.hide()
	shade.hide()
	trail.paused = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()
	queue_redraw()


func steer(direction: Vector2i) -> void:
	if mode.is_empty():
		trail.turn(direction)


func show_menu(next_mode: String) -> void:
	mode = next_mode
	trail.paused = true
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
		heading = "Every strand, gathered!" if mode == "won" else "All tangled up!"
		copy = "You gathered %d yarn balls.\nScore  %s  ·  Best  %s" % [trail.score / 10, format_score(trail.score), format_score(host.trail_best)]
		cta = "Try again"
	host.make_label("PURR & TANGLE · YARN TRAIL", 14, column)
	host.make_label(heading, 25, column)
	if mode != "pause":
		add_outcome_art(column, mode, 170.0)
	host.make_label(copy, 17, column)
	host.make_button(cta, Vector2.ZERO, Vector2(450, 46), resume if mode == "pause" else restart, column)
	if mode == "pause":
		host.make_button("Start over", Vector2.ZERO, Vector2(450, 40), restart, column)
	host.make_button("Main menu", Vector2.ZERO, Vector2(450, 40), host.return_to_title, column)
	host.make_label("Gather yarn balls. Stay inside the basket\nand never cross your own strand.", 14, column)
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
	for action in TURNS:
		if event.is_action_pressed(action):
			trail.turn(TURNS[action])
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_W:
		trail.turn(Vector2i.UP)
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or not mode.is_empty():
		return
	var score := trail.score
	trail.tick(minf(delta, 0.1))
	if trail.score != score:
		host.play_cat(520.0 + mini(trail.cells.size(), 20) * 20.0, 0.2)
	if trail.over:
		if not trail.won:
			host.play_cat(110.0, 0.3, true)
		if trail.score > host.trail_best:
			host.trail_best = trail.score
			host.save_settings()
		show_menu("won" if trail.won else "lost")
	queue_redraw()


func center(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2.ONE * 0.5) * CELL


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CREAM)
	draw_circle(Vector2(40, 80), 240, Color("e8e9d7"))
	draw_circle(Vector2(1050, 880), 220, Color("dde4d3"))
	text_at("PURR & TANGLE", Vector2(152, 52), 21, INK, title_font)
	text_at("YARN TRAIL", Vector2(152, 80), 14, MUTED)
	text_at("SCORE  " + format_score(trail.score), Vector2(152, 112), 17, INK)
	text_at("BEST  " + format_score(maxi(host.trail_best, trail.score)), Vector2(330, 112), 15, MUTED)
	text_at("%d YARN BALLS GATHERED" % (trail.score / 10), Vector2(720, 112), 15, MUTED)
	var rect := Rect2(ORIGIN, Vector2(Trail.WIDTH, Trail.HEIGHT) * CELL)
	card(rect.grow(24), Color("b98f5d"), 22)
	card(rect.grow(7), Color("574d37"), 10)
	card(rect, Color("233e38"), 6)
	for y in range(Trail.HEIGHT):
		for x in range(Trail.WIDTH):
			draw_circle(center(Vector2i(x, y)), 1, Color("486055"))
	for i in range(1, trail.cells.size()):
		var color: Color = COLORS[trail.colors[i]]
		draw_line(center(trail.cells[i - 1]), center(trail.cells[i]), color, CELL * 0.3, true)
		draw_circle(center(trail.cells[i]), CELL * 0.15, color)
	# Pattern marks tell colors apart in the puzzle; here color is only decoration.
	show_patterns = false
	if not trail.won:
		draw_piece(center(trail.yarn), trail.yarn_color, true, CELL)
	draw_piece(center(trail.cells[0]), 0, false, CELL * 1.3)
	if mode.is_empty() and not trail.moving:
		card(Rect2(376, 742, 348, 34), CREAM, 10)
		text_at("Pick a direction to set off", Vector2(446, 765), 16, INK)
	text_at("ARROWS / WASD / STICK  STEER", Vector2(152, 870), 12, MUTED)
	text_at("A long strand. A careful kitten.", Vector2(680, 870), 16, MUTED, title_font)
