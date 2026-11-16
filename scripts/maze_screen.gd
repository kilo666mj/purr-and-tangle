extends "res://scripts/side_screen.gd"
## Treat maze presentation: hedge walls, treats, one kitten and two yarn tangles.

const Maze = preload("res://scripts/maze.gd")


func _init() -> void:
	game = Maze.new()
	title = "TREAT MAZE"
	tagline = "So many treats. So little time."
	rules = "Eat every treat. Keep away from the tangles.\nThree catches and the game is over."
	lost_heading = "Caught in a tangle!"
	origin = Vector2(220, 170)
	grid = Vector2i(Maze.WIDTH, Maze.HEIGHT)


func summary() -> String:
	return "Maze %d  ·  %d of %d catches" % [game.level, game.catches, Maze.CATCHES]


func advance(delta: float) -> void:
	var catches: int = game.catches
	game.tick(delta)
	if game.catches != catches and not game.over:
		host.play_cat(110.0, 0.15, true)


func draw_board() -> void:
	for y in range(Maze.HEIGHT):
		for x in range(Maze.WIDTH):
			var at := Vector2i(x, y)
			if not game.open(at):
				card(Rect2(center(at) - Vector2.ONE * cell * 0.5, Vector2.ONE * cell).grow(-2), Color("3a5a4e"), 8)
			elif game.treats.has(at):
				draw_circle(center(at), 5, Color("e7b563"))
	for i in range(game.chasers.size()):
		draw_piece(center(game.chasers[i]), 1 + i, true, cell)
	draw_piece(center(game.cat), 0, false, cell * 1.15)


func showcase() -> void:
	for at in [Vector2i(1, 8), Vector2i(1, 7), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)]:
		game.treats.erase(at)
	game.cat = Vector2i(6, 5)
	game.chasers.assign([Vector2i(10, 3), Vector2i(4, 9)])
	game.score = 90
