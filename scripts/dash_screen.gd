extends "res://scripts/side_screen.gd"
## Kitchen dash presentation: lanes of vacuums and yarn between the kitten and its cushion.

const Dash = preload("res://scripts/dash.gd")
const YARNS := ["yarn_orange", "yarn_blue", "yarn_purple"]

var shown_cat := Vector2.ZERO  # Where the kitten is drawn, easing toward its cell.


func _init() -> void:
	game = Dash.new()
	title = "KITCHEN DASH"
	tagline = "A busy floor. A brave kitten."
	rules = "Cross to the cushion at the top.\nThree bumps and the game is over."
	lost_heading = "Bumped once too often!"
	origin = Vector2(264, 160)
	cell = 52.0
	grid = Vector2i(Dash.WIDTH, Dash.HEIGHT)


func summary() -> String:
	return "%d crossings  ·  %d of %d bumps" % [game.crossings, game.bumps, Dash.BUMPS]


func advance(delta: float) -> void:
	var bumps: int = game.bumps
	game.tick(delta)
	if game.bumps != bumps and not game.over:
		host.play_cat(110.0, 0.15, true)
	# Ease single steps; snap the jump back to the start, and everything under reduced motion.
	var target := Vector2(game.cat)
	var far: bool = shown_cat.distance_to(target) > 1.5
	shown_cat = target if far or host.reduced_motion else shown_cat.lerp(target, 1.0 - exp(-delta * 22.0))


func glide(lane: Dictionary, x: int) -> float:
	# Hazards slide through their cell between steps, never drawn more than half a cell from
	# where the rules place them.
	return x if host.reduced_motion else x + lane.dir * (lane.clock / lane.interval - 0.5)


func draw_board() -> void:
	for row in [0, Dash.REST_ROW, Dash.HEIGHT - 1]:
		var safe := Rect2(origin + Vector2(0, row * cell), Vector2(grid.x * cell, cell)).grow(-3)
		card(safe, Color("d7b98b") if row == 0 else Color("3a5a4e"), 8)
	text_at("♥  CUSHION  ♥", center(Vector2i(4, 0)) + Vector2(-26, 6), 15, INK)
	for row in game.lanes:
		var lane: Dictionary = game.lanes[row]
		for x in lane.cells:
			var along := glide(lane, x)
			var spot := origin + Vector2(along + 0.5, row + 0.5) * cell
			# Fade at the walls, where a hazard leaves one side and returns on the other.
			var fade := clampf(minf(along + 0.5, Dash.WIDTH - 0.5 - along) * 2.0, 0.0, 1.0)
			if row % 2 == 0:
				draw_texture_rect(textures[YARNS[row % 3]], Rect2(spot - Vector2.ONE * cell * 0.45, Vector2.ONE * cell * 0.9), false, Color(1, 1, 1, fade))
			else:
				# Robot vacuum: a shape of its own, so lanes differ by more than color.
				draw_circle(spot, cell * 0.4, Color(Color("8d9aa0"), fade))
				draw_circle(spot, cell * 0.28, Color(Color("4d5a60"), fade))
				draw_circle(spot + Vector2(lane.dir * cell * 0.22, 0), 4, Color(Color("9ee08a"), fade))
	draw_piece(origin + (shown_cat + Vector2.ONE * 0.5) * cell, 2, false, cell * 1.05)


func showcase() -> void:
	game.cat = Vector2i(6, 4)
	shown_cat = Vector2(game.cat)
	game.score = 100
	game.crossings = 2
	game.bumps = 1
