extends "res://scripts/side_screen.gd"
## Shelf swat presentation: four full shelves, a yarn ball and a kitten on a cushion.

const Swat = preload("res://scripts/swat.gd")


func _init() -> void:
	game = Swat.new()
	title = "SHELF SWAT"
	tagline = "Tidy shelves. Not for long."
	rules = "Keep the yarn ball in the air and knock\neverything off the shelves. Three drops end it."
	lost_heading = "The yarn rolled away!"
	hint = "← →  /  A D  /  STICK   MOVE THE CUSHION"
	origin = Vector2(238, 160)
	cell = 48.0
	grid = Vector2i(Swat.WIDTH, Swat.HEIGHT)


func summary() -> String:
	return "Room %d  ·  %d of %d drops" % [game.level, game.drops, Swat.DROPS]


func advance(delta: float) -> void:
	var drops: int = game.drops
	game.tick(delta, Input.get_axis("left", "right"))
	if game.drops != drops and not game.over:
		host.play_cat(110.0, 0.15, true)


func at(point: Vector2) -> Vector2:
	return origin + point * cell


func draw_board() -> void:
	for y in Swat.SHELVES:
		draw_line(at(Vector2(0, y + 1)), at(Vector2(Swat.WIDTH, y + 1)), Color("b98f5d"), 3)
	for item in game.items:
		# Books, jars and boxes: three silhouettes, so shelves differ by more than color.
		var kind: int = game.items[item]
		var box := Rect2(at(Vector2(item)), Vector2.ONE * cell)
		box = box.grow_individual(-9 - kind * 3, -4 - kind * 6, -9 - kind * 3, -2)
		card(box, COLORS[kind], 4 + kind * 6)
	draw_piece(at(Vector2(game.cushion, Swat.CUSHION_Y + 0.5)), 0, false, cell * 1.05)
	card(Rect2(at(Vector2(game.cushion - Swat.HALF, Swat.CUSHION_Y)), Vector2(Swat.HALF * 2, 0.3) * cell), Color("d7b98b"), 7)
	if not game.over:
		draw_piece(at(game.ball), 2, true, cell * 0.75)


func showcase() -> void:
	for item in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(5, 3), Vector2i(6, 3), Vector2i(9, 4), Vector2i(10, 4)]:
		game.items.erase(item)
	game.cushion = 5.0
	game.ball = Vector2(7.2, 6.4)
	game.score = 80
	game.knocked = 8
