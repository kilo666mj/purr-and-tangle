extends SceneTree

const Swat = preload("res://scripts/swat.gd")

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh(seed_value: int = 7) -> RefCounted:
	var game := Swat.new()
	game.start(seed_value)
	return game


func _initialize() -> void:
	var game := fresh()
	expect(game.items.size() == 52 and not game.moving, "A run starts with four full shelves and the ball at rest")
	game.tick(0.5, 1.0)
	expect(game.cushion > 6.5 and is_equal_approx(game.ball.x, game.cushion) and game.velocity == Vector2.ZERO, "The resting ball rides the cushion")
	game.tick(10.0, 1.0)
	expect(is_equal_approx(game.cushion, Swat.WIDTH - Swat.HALF), "The cushion stays in the room")
	game.paused = true
	game.tick(1.0, -1.0)
	expect(is_equal_approx(game.cushion, Swat.WIDTH - Swat.HALF), "Pause freezes the cushion")
	game.paused = false
	game.turn(Vector2i.LEFT)
	expect(game.moving and game.velocity.y < 0.0 and is_equal_approx(game.velocity.length(), game.speed()), "A turn serves the ball upward at full speed")

	game = fresh()
	game.moving = true
	game.ball = Vector2(6.5, 5.6)
	game.velocity = Vector2(0, -6)
	game.step(0.2)
	expect(game.items.size() == 51 and not game.items.has(Vector2i(6, 4)) and game.score == 10 and game.velocity.y > 0.0, "Hitting an item knocks it off and bounces the ball")
	game.ball = Vector2(0.4, 7.0)
	game.velocity = Vector2(-6, 1)
	game.step(0.1)
	expect(game.velocity.x > 0.0 and game.ball.x >= Swat.RADIUS, "Walls bounce the ball")
	game.items.clear()
	game.items[Vector2i(0, 4)] = 0
	game.ball = Vector2(6.5, 0.4)
	game.velocity = Vector2(0, -6)
	game.step(0.1)
	expect(game.velocity.y > 0.0, "The ceiling bounces the ball")

	game.cushion = 6.5
	game.ball = Vector2(7.3, 9.6)
	game.velocity = Vector2(0, 6)
	game.step(0.05)
	expect(game.velocity.y < 0.0 and game.velocity.x > 0.0, "The cushion returns the ball, aimed by where it lands")
	game.ball = Vector2(1.0, 9.6)
	game.velocity = Vector2(0, 6)
	for i in range(20):
		game.step(0.05)
	expect(game.drops == 1 and not game.moving and not game.over and is_equal_approx(game.ball.x, game.cushion), "A missed ball is a drop and a new serve")
	game.drops = Swat.DROPS - 1
	game.moving = true
	game.ball = Vector2(1.0, 11.2)
	game.velocity = Vector2(0, 6)
	game.step(0.05)
	expect(game.over, "Three drops end the run")
	var cushion: float = game.cushion
	game.turn(Vector2i.LEFT)
	game.tick(1.0, -1.0)
	expect(game.cushion == cushion and not game.moving, "A finished run ignores input")

	game = fresh()
	game.items.clear()
	game.items[Vector2i(6, 4)] = 0
	game.moving = true
	game.ball = Vector2(6.5, 5.6)
	game.velocity = Vector2(0, -6)
	game.step(0.2)
	expect(game.level == 2 and game.items.size() == 52 and game.score == 110 and not game.moving, "Clearing the shelves restocks a faster room")
	expect(game.speed() > fresh().speed(), "Each room is faster")
	game.knocked = 5000
	expect(is_equal_approx(game.speed(), 12.0), "Speed has a ceiling")
	var served := fresh(42)
	var again := fresh(42)
	served.turn(Vector2i.UP)
	again.turn(Vector2i.UP)
	expect(served.velocity == again.velocity, "Seeded runs serve identically")

	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var sound := true
	for run in range(60):
		game = fresh(run)
		for i in range(600):
			if game.over:
				break
			if not game.moving:
				game.turn(Vector2i.UP)
			# A long frame must not let the ball tunnel through anything.
			game.tick(dice.randf_range(0.01, 0.1), dice.randi_range(-1, 1))
			if game.ball.x < Swat.RADIUS - 0.001 or game.ball.x > Swat.WIDTH - Swat.RADIUS + 0.001 or game.ball.y < Swat.RADIUS - 0.001:
				sound = false
			if game.moving and (absf(game.velocity.y) < 1.0 or game.items.has(Vector2i(floori(game.ball.x), floori(game.ball.y)))):
				sound = false
			if game.score != game.knocked * 10 + (game.level - 1) * 100:
				sound = false
	expect(sound, "Random play keeps the ball in the room, moving, and outside every item")

	print("Shelf swat rules: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
