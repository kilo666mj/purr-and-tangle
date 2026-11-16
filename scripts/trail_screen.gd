extends "res://scripts/side_screen.gd"
## Yarn trail presentation: one basket, one kitten, one ever-longer strand.

const Trail = preload("res://scripts/trail.gd")


func _init() -> void:
	game = Trail.new()
	title = "YARN TRAIL"
	tagline = "A long strand. A careful kitten."
	rules = "Gather yarn balls. Stay inside the basket\nand never cross your own strand."
	lost_heading = "All tangled up!"
	won_heading = "Every strand, gathered!"
	origin = Vector2(176, 150)
	grid = Vector2i(Trail.WIDTH, Trail.HEIGHT)


func summary() -> String:
	return "%d yarn balls gathered" % (game.score / 10)


func draw_board() -> void:
	for i in range(1, game.cells.size()):
		var color: Color = COLORS[game.colors[i]]
		draw_line(center(game.cells[i - 1]), center(game.cells[i]), color, cell * 0.3, true)
		draw_circle(center(game.cells[i]), cell * 0.15, color)
	if not game.won:
		draw_piece(center(game.yarn), game.yarn_color, true, cell)
	draw_piece(center(game.cells[0]), 0, false, cell * 1.3)


func showcase() -> void:
	game.cells.assign([Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5), Vector2i(9, 6), Vector2i(8, 6), Vector2i(7, 6), Vector2i(6, 6), Vector2i(6, 7), Vector2i(6, 8), Vector2i(5, 8)])
	game.colors.assign([0, 0, 0, 0, 1, 1, 2, 0, 1, 2])
	game.yarn = Vector2i(12, 4)
	game.score = 70
	game.heading = Vector2i.UP
