extends "res://scripts/side_screen.gd"
## Laser pounce presentation: one room, one kitten, one restless red dot.

const Pounce = preload("res://scripts/pounce.gd")
const RED := Color("ff5a4a")


func _init() -> void:
	game = Pounce.new()
	title = "LASER POUNCE"
	tagline = "A quick paw. A quicker dot."
	rules = "Reach the red dot before its ring runs out.\nThree escapes and the game is over."
	lost_heading = "The dot got away!"
	origin = Vector2(226, 170)
	cell = 72.0
	grid = Vector2i(Pounce.WIDTH, Pounce.HEIGHT)


func summary() -> String:
	return "%d pounces  ·  %d of %d escapes" % [game.pounces, game.misses, Pounce.ESCAPES]


func advance(delta: float) -> void:
	var misses: int = game.misses
	game.tick(delta)
	if game.misses != misses and not game.over:
		host.play_cat(110.0, 0.15, true)


func draw_board() -> void:
	if not game.over:
		var spot := center(game.dot)
		draw_circle(spot, 20, Color(RED, 0.25))
		draw_circle(spot, 8, RED)
		# The ring empties as the dot's time runs out: a shape cue, not a color one.
		draw_arc(spot, 28, -PI / 2, -PI / 2 + TAU * game.time_left / game.time_total, 40, RED, 3, true)
	draw_piece(center(game.cat), 1, false, cell * 0.95)


func showcase() -> void:
	game.cat = Vector2i(2, 4)
	game.dot = Vector2i(6, 2)
	game.time_left = game.time_total * 0.7
	game.score = 130
	game.pounces = 8
	game.misses = 1
