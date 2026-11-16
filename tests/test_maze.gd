extends SceneTree

const Maze = preload("res://scripts/maze.gd")

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh(seed_value: int = 7) -> RefCounted:
	var game := Maze.new()
	game.start(seed_value)
	return game


func park(game: RefCounted) -> void:
	# Keep the tangles out of the way for a step-by-step check.
	game.chasers.assign([Vector2i(13, 1), Vector2i(13, 1)])


func _initialize() -> void:
	var game := fresh()
	var rows_ok := Maze.MAP.size() == Maze.HEIGHT
	for row in Maze.MAP:
		rows_ok = rows_ok and row.length() == Maze.WIDTH
	expect(rows_ok, "The map matches its stated size")
	# Flood fill: every treat must be reachable, with no dead ends to be trapped in.
	var seen := {Maze.CAT_START: true}
	var queue: Array[Vector2i] = [Maze.CAT_START]
	var dead_ends := 0
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		var exits := 0
		for side in Maze.SIDES:
			if game.open(at + side):
				exits += 1
				if not seen.has(at + side):
					seen[at + side] = true
					queue.append(at + side)
		if exits < 2:
			dead_ends += 1
	expect(seen.size() == game.treats.size() + 1, "Every open cell is reachable from the start")
	expect(dead_ends == 0, "The maze has no dead ends")
	expect(game.open(Maze.CAT_START) and Maze.CHASER_STARTS.all(func(at): return game.open(at)), "Everyone starts on open floor")

	game.tick(10.0)
	expect(game.cat == Maze.CAT_START and game.chasers[0] == Maze.CHASER_STARTS[0], "Nothing moves before the first turn")
	park(game)
	game.turn(Vector2i.DOWN)
	game.step_cat()
	expect(game.cat == Maze.CAT_START, "Walls stop the kitten")
	game.turn(Vector2i.RIGHT)
	game.step_cat()
	expect(game.cat == Vector2i(2, 9) and game.score == 10 and not game.treats.has(Vector2i(2, 9)), "Moving onto a treat eats it")
	game.turn(Vector2i.UP)
	game.step_cat()
	expect(game.cat == Vector2i(3, 9) and game.wanted == Vector2i.UP, "A turn into a wall waits while the kitten carries on")
	game.step_cat()
	game.step_cat()
	expect(game.cat == Vector2i(4, 8), "The waiting turn is taken at the next opening")
	game.paused = true
	game.tick(10.0)
	expect(game.cat == Vector2i(4, 8), "Pause freezes the maze")
	game.paused = false

	game = fresh()
	game.turn(Vector2i.RIGHT)
	game.chasers.assign([Vector2i(2, 9), Vector2i(13, 1)])
	game.step_cat()
	expect(game.catches == 1 and game.cat == Maze.CAT_START and not game.moving and not game.over, "Running into a tangle is a catch and a reset")
	game.turn(Vector2i.RIGHT)
	game.chasers.assign([Vector2i(2, 9), Vector2i(13, 1)])
	game.chaser_headings.assign([Vector2i.LEFT, Vector2i.ZERO])
	game.step_chasers()
	expect(game.catches == 2, "A tangle reaching the kitten is a catch")
	game.catches = Maze.CATCHES - 1
	game.caught()
	expect(game.over, "Three catches end the run")

	game = fresh()
	park(game)
	game.treats.clear()
	game.treats[Vector2i(2, 9)] = true
	game.turn(Vector2i.RIGHT)
	game.step_cat()
	expect(game.level == 2 and game.score == 110 and game.treats.size() == seen.size() - 1 and game.cat == Maze.CAT_START, "Clearing the maze refills it with a bonus")
	expect(game.chaser_pace() < fresh().chaser_pace(), "Tangles speed up each maze")
	game.level = 50
	expect(game.chaser_pace() >= Maze.CAT_PACE, "Tangles never outpace the kitten")

	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var sound := true
	for run in range(60):
		game = fresh(run)
		for i in range(400):
			if game.over:
				break
			game.turn(Maze.SIDES[dice.randi_range(0, 3)])
			game.tick(0.1)
			if not game.open(game.cat) or game.treats.has(game.cat):
				sound = false
			for chaser in game.chasers:
				if not game.open(chaser) or (chaser == game.cat and game.moving):
					sound = false
	expect(sound, "Random play keeps everyone on open floor and never overlapping")

	print("Treat maze rules: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
