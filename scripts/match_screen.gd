extends "res://scripts/side_screen.gd"
## Kitten match presentation: a table of face-down cards and a paw-shaped cursor.

const Match = preload("res://scripts/match.gd")
const KINDS := ["cat_orange", "cat_blue", "cat_purple", "yarn_orange", "yarn_blue", "yarn_purple"]


func _init() -> void:
	game = Match.new()
	title = "KITTEN MATCH"
	tagline = "A good memory. A full basket."
	rules = "Flip two cards to find a pair.\nPlain and starred cards are different."
	lost_heading = "Out of guesses!"
	won_heading = "Every kitten, paired!"
	action = "Flip"
	hint = "ARROWS / WASD / STICK  MOVE     ENTER / SPACE / A  FLIP"
	origin = Vector2(250, 190)
	cell = 100.0
	grid = Vector2i(Match.WIDTH, Match.HEIGHT)


func summary() -> String:
	return "%d of 12 pairs  ·  %d of %d misses" % [game.pairs, game.misses, Match.MISSES]


func advance(delta: float) -> void:
	var misses: int = game.misses
	game.tick(delta)
	if game.misses != misses and not game.over:
		host.play_cat(110.0, 0.15, true)


func draw_board() -> void:
	for index in range(game.faces.size()):
		var at := Vector2i(index % Match.WIDTH, index / Match.WIDTH)
		var face := Rect2(center(at) - Vector2.ONE * cell * 0.44, Vector2.ONE * cell * 0.88)
		if not game.shown(index):
			card(face, Color("b98f5d"), 12)
			card(face.grow(-6), Color("d3ad76"), 8)
			text_at("♥", center(at) + Vector2(-9, 9), 26, Color("b98f5d"))
			continue
		# Twelve kinds from six pictures: the second set sits on a gold, starred card.
		var starred: bool = game.faces[index] >= KINDS.size()
		card(face, Color("e7b563") if starred else CREAM, 12)
		var picture: Texture2D = textures[KINDS[game.faces[index] % KINDS.size()]]
		draw_texture_rect(picture, face.grow(-8), false, Color(1, 1, 1, 0.55 if game.matched[index] else 1.0))
		if starred:
			text_at("★", face.position + Vector2(6, 22), 20, INK)
	if not game.over:
		var spot := Rect2(center(game.cursor) - Vector2.ONE * cell * 0.48, Vector2.ONE * cell * 0.96)
		draw_style_box(panel_style(Color.TRANSPARENT, 14, Color.WHITE, 4), spot)


func showcase() -> void:
	for index in [0, 1, 7, 8, 14, 20]:
		game.matched[index] = true
	game.picked.assign([3, 16])
	game.cursor = Vector2i(4, 2)
	game.pairs = 3
	game.misses = 4
	game.score = 60
