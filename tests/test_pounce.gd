extends SceneTree

const Pounce = preload("res://scripts/pounce.gd")

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh(seed_value: int = 7) -> RefCounted:
	var game := Pounce.new()
	game.start(seed_value)
	return game


func distance(game: RefCounted) -> int:
	return absi(game.dot.x - game.cat.x) + absi(game.dot.y - game.cat.y)


func _initialize() -> void:
	var game := fresh()
	expect(game.cat == Vector2i(4, 3) and distance(game) >= 3, "A run starts in the middle with the dot out of reach")
	var allowed: float = game.time_left
	game.tick(30.0)
	expect(game.time_left == allowed and game.misses == 0, "The dot waits for the first move")

	game.dot = Vector2i(6, 3)
	game.turn(Vector2i.RIGHT)
	expect(game.cat == Vector2i(5, 3) and game.moving and game.pounces == 0, "A move steps one cell")
	game.paused = true
	game.tick(30.0)
	expect(game.misses == 0, "Pause freezes the dot")
	game.paused = false
	game.turn(Vector2i.RIGHT)
	expect(game.pounces == 1 and game.score == 20, "An instant pounce scores double")
	expect(distance(game) >= 3 and is_equal_approx(game.time_left, 0.6 + distance(game) * game.pace()), "The next dot is out of reach with time scaled to its distance")

	game = fresh()
	game.dot = Vector2i(6, 3)
	game.turn(Vector2i.RIGHT)
	game.time_left = 0.01
	game.turn(Vector2i.RIGHT)
	expect(game.score == 10, "A last-moment pounce scores the base amount")

	game = fresh()
	for i in range(20):
		game.turn(Vector2i.LEFT)
		game.turn(Vector2i.UP)
		game.dot = Vector2i(8, 6)
	expect(game.cat == Vector2i.ZERO, "The kitten stays inside the room")

	game = fresh()
	game.dot = Vector2i(8, 6)
	game.turn(Vector2i.LEFT)
	game.tick(30.0)
	expect(game.misses == 1 and not game.over and game.time_left > 0.0, "An escaped dot costs a miss and darts elsewhere")
	game.tick(30.0)
	game.tick(30.0)
	expect(game.over and game.misses == Pounce.ESCAPES, "Three escapes end the run")
	var cat: Vector2i = game.cat
	game.turn(Vector2i.RIGHT)
	expect(game.cat == cat, "A finished run ignores moves")

	expect(fresh().pace() > 0.14, "Early dots are generous")
	game = fresh()
	game.pounces = 500
	expect(is_equal_approx(game.pace(), 0.14), "Speed has a floor")
	expect(fresh(42).dot == fresh(42).dot, "Seeded runs place the dot identically")

	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var sound := true
	for run in range(200):
		game = fresh(run)
		for i in range(300):
			game.turn([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][dice.randi_range(0, 3)])
			game.tick(0.05)
			if game.over:
				break
			if game.cat == game.dot or distance(game) > Pounce.WIDTH + Pounce.HEIGHT or game.time_left <= 0.0 or game.time_left > game.time_total:
				sound = false
			if game.cat.x < 0 or game.cat.y < 0 or game.cat.x >= Pounce.WIDTH or game.cat.y >= Pounce.HEIGHT:
				sound = false
	expect(sound, "Random play keeps the kitten in the room and the dot live and elsewhere")

	print("Laser pounce rules: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
