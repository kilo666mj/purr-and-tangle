extends "res://scripts/puzzle_art.gd"
## One basket's visuals. Each view owns its own animation state.

const Board = preload("res://scripts/board.gd")
const BOARD_ORIGIN := Vector2.ZERO
const CELL := 40.0
var session: PuzzleSession
var reduced_motion := false
var fx: Array = []
var elapsed := 0.0
var visual_positions: Dictionary = {}
var active_visual: Array = []
var active_stamp := -1


func reset() -> void:
	fx.clear()
	visual_positions.clear()
	active_visual.clear()
	active_stamp = -1
	queue_redraw()


func animate(delta: float, before: int) -> void:
	if before == Board.Phase.CLEARING and session.board.phase == Board.Phase.GRAVITY:
		for cleared in session.board.last_clear:
			fx.append({"pos": Vector2(cleared.pos), "color": cleared.color, "yarn": cleared.yarn, "age": 0.0})
	if not session.paused:
		elapsed += delta
		for effect in fx:
			effect.age += delta
		fx = fx.filter(func(effect): return effect.age < 0.7)
	update_visual_positions(delta)
	queue_redraw()


func update_visual_positions(delta: float) -> void:
	var weight := 1.0 if reduced_motion else 1.0 - exp(-24.0 * delta)
	var alive: Dictionary = {}
	for y in range(Board.HEIGHT):
		for x in range(Board.WIDTH):
			var cell: Variant = session.board.at(Vector2i(x, y))
			if cell == null:
				continue
			var target := Vector2(x, y)
			var current: Vector2 = visual_positions.get(cell.uid, target)
			alive[cell.uid] = current.lerp(target, weight)
	visual_positions = alive
	var positions := session.board.active_positions()
	if positions.is_empty():
		active_visual = []
	elif active_visual.is_empty() or active_stamp != session.board.pair_serial:
		active_stamp = session.board.pair_serial
		active_visual = [Vector2(positions[0]), Vector2(positions[1])]
	else:
		for i in range(2):
			active_visual[i] = active_visual[i].lerp(Vector2(positions[i]), weight)



func piece_center(pos: Vector2i) -> Vector2:
	var cell: Variant = session.board.at(pos)
	var visual := Vector2(pos)
	if cell != null:
		visual = visual_positions.get(cell.uid, visual)
	return BOARD_ORIGIN + (visual + Vector2.ONE * 0.5) * CELL



func _draw() -> void:
	var rect := Rect2(BOARD_ORIGIN, Vector2(Board.WIDTH, Board.HEIGHT) * CELL)
	card(rect.grow(24), Color("b98f5d"), 22)
	# Wicker stays outside the quiet grid so tiny pieces remain readable.
	for y in range(-12, 655, 12):
		draw_line(Vector2(-22, y), Vector2(342, y - 3), Color("d3ad76"), 3)
	card(rect.grow(7), Color("574d37"), 10)
	card(rect, Color("233e38"), 6)
	for y in range(Board.HEIGHT):
		for x in range(Board.WIDTH):
			var pos := Vector2i(x, y)
			draw_circle(BOARD_ORIGIN + (Vector2(pos) + Vector2.ONE * 0.5) * CELL, 1, Color("486055"))
			var center := piece_center(pos)
			var cell: Variant = session.board.at(pos)
			if cell != null:
				if cell.bond > 0:
					for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
						var other: Variant = session.board.at(pos + dir)
						if other != null and other.bond == cell.bond:
							draw_yarn_link(center, piece_center(pos + dir))
				var pulse := 1.0
				if session.board.matches.has(pos):
					draw_circle(center, CELL * 0.48, Color("f3dc8f"))
					if not reduced_motion:
						pulse = 1.0 + sin(elapsed * 25.0) * 0.07
				draw_piece(center, cell.color, cell.yarn, CELL * pulse)
	var positions := session.board.active_positions()
	if positions.size() == 2:
		var ghost := session.board.ghost_positions()
		for i in range(2):
			var center := BOARD_ORIGIN + (Vector2(ghost[i]) + Vector2.ONE * 0.5) * CELL
			draw_arc(center, CELL * 0.41, 0, TAU, 32, Color(COLORS[session.board.active.colors[i]], 0.42), 2, true)
		if active_visual.size() == 2:
			positions = active_visual
		var first := BOARD_ORIGIN + (Vector2(positions[0]) + Vector2.ONE * 0.5) * CELL
		var second := BOARD_ORIGIN + (Vector2(positions[1]) + Vector2.ONE * 0.5) * CELL
		draw_yarn_link(first, second)
		for i in range(2):
			var center := BOARD_ORIGIN + (Vector2(positions[i]) + Vector2.ONE * 0.5) * CELL
			draw_piece(center, session.board.active.colors[i], false, CELL)
	for effect in fx:
		var center: Vector2 = BOARD_ORIGIN + (effect.pos + Vector2.ONE * 0.5) * CELL
		if not reduced_motion:
			center.y -= effect.age * 60.0
		var alpha: float = 1.0 - effect.age / 0.7
		var radius: float = 16.0 if reduced_motion else 8 + effect.age * 32
		draw_arc(center, radius, 0, TAU, 24, Color(COLORS[effect.color], alpha), 2, true)
		if effect.yarn:
			text_at("♥", center + Vector2(-6, 0), 21, Color(CREAM, alpha))

