extends SceneTree

const Match = preload("res://scripts/match.gd")

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh(seed_value: int = 7) -> RefCounted:
	var game := Match.new()
	game.start(seed_value)
	return game


func flip(game: RefCounted, index: int) -> void:
	game.cursor = Vector2i(index % Match.WIDTH, index / Match.WIDTH)
	game.act()


func partner(game: RefCounted, index: int) -> int:
	for other in range(game.faces.size()):
		if other != index and game.faces[other] == game.faces[index]:
			return other
	return -1


func stranger(game: RefCounted, index: int) -> int:
	for other in range(game.faces.size()):
		if game.faces[other] != game.faces[index] and not game.shown(other):
			return other
	return -1


func _initialize() -> void:
	var game := fresh()
	var counts := {}
	for face in game.faces:
		counts[face] = counts.get(face, 0) + 1
	expect(game.faces.size() == 24 and counts.size() == 12 and counts.values().all(func(count): return count == 2), "The table holds twelve pairs")
	expect(fresh(42).faces == fresh(42).faces and fresh(1).faces != fresh(2).faces, "Seeded runs shuffle identically, different seeds differently")

	game.turn(Vector2i.LEFT)
	game.turn(Vector2i.UP)
	expect(game.cursor == Vector2i.ZERO and game.moving, "The cursor stays on the table")
	game.turn(Vector2i.RIGHT)
	game.turn(Vector2i.DOWN)
	expect(game.cursor == Vector2i(1, 1), "The cursor moves one card at a time")

	flip(game, 0)
	expect(game.shown(0) and game.picked == [0], "A flip turns one card face up")
	flip(game, 0)
	expect(game.picked == [0], "Flipping the same card again does nothing")
	flip(game, partner(game, 0))
	expect(game.pairs == 1 and game.score == 20 and game.matched[0] and game.picked.is_empty(), "A pair stays face up and scores")
	flip(game, 0)
	expect(game.picked.is_empty(), "A matched card cannot be picked")

	var first := stranger(game, 0)
	flip(game, first)
	var second := stranger(game, first)
	flip(game, second)
	expect(game.misses == 1 and game.picked.size() == 2 and game.shown(first), "A mismatch stays up briefly and counts a miss")
	game.paused = true
	game.tick(5.0)
	expect(game.picked.size() == 2, "Pause keeps the mismatch showing")
	game.paused = false
	game.tick(Match.PEEK)
	expect(game.picked.is_empty() and not game.shown(first), "The mismatch flips back")
	flip(game, first)
	flip(game, second)
	flip(game, first)
	expect(game.picked == [first] and game.misses == 2, "Flipping during a peek dismisses it and starts a new pick")

	game = fresh()
	for index in range(game.faces.size()):
		if not game.matched[index]:
			flip(game, index)
			flip(game, partner(game, index))
	expect(game.won and game.over and game.pairs == 12 and game.score == 240 + 10 * Match.MISSES, "Pairing everything wins with a bonus for unused misses")

	game = fresh()
	for i in range(Match.MISSES):
		flip(game, 0)
		flip(game, stranger(game, 0))
	expect(game.over and not game.won and game.misses == Match.MISSES, "Too many misses end the run")
	var score: int = game.score
	flip(game, 0)
	game.turn(Vector2i.RIGHT)
	expect(game.score == score and game.picked.size() == 2, "A finished run ignores input")

	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var sound := true
	for run in range(100):
		game = fresh(run)
		for i in range(400):
			if game.over:
				break
			game.turn([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][dice.randi_range(0, 3)])
			if dice.randi_range(0, 1) == 0:
				game.act()
			game.tick(0.3)
			if game.picked.size() > 2 or game.pairs * 2 != game.matched.count(true) or game.score != game.pairs * 20:
				sound = false
			for index in game.picked:
				if game.matched[index]:
					sound = false
	expect(sound, "Random play keeps picks, pairs and score consistent")

	print("Kitten match rules: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
