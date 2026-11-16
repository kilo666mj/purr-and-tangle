extends SceneTree

const Dash = preload("res://scripts/dash.gd")

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh(seed_value: int = 7) -> RefCounted:
	var game := Dash.new()
	game.start(seed_value)
	return game


func empty(game: RefCounted) -> void:
	for row in game.lanes:
		game.lanes[row].cells.clear()


func _initialize() -> void:
	var game := fresh()
	expect(game.cat == Vector2i(5, 8) and game.lanes.size() == 6 and not game.lanes.has(Dash.REST_ROW), "A run starts at the bottom with six lanes and a rest row")
	var gaps := true
	for run in range(50):
		game = fresh(run)
		for row in game.lanes:
			var cells: Array = game.lanes[row].cells
			if cells.size() < 2 or cells.size() > 3 or cells.size() >= Dash.WIDTH - 2:
				gaps = false
	expect(gaps, "Every lane has hazards and room to pass")

	game = fresh()
	var lane: Dictionary = game.lanes[7]
	lane.cells.assign([0])
	lane.interval = 0.5
	lane.clock = 0.0
	game.paused = true
	game.tick(5.0)
	expect(lane.cells == [0], "Pause freezes the lanes")
	game.paused = false
	game.tick(0.5)
	expect(lane.cells == [posmod(lane.dir, Dash.WIDTH)], "Hazards advance one cell per interval and wrap")

	game = fresh()
	empty(game)
	game.lanes[7].cells.assign([5])
	game.turn(Vector2i.UP)
	expect(game.bumps == 1 and game.cat == Vector2i(5, 8) and not game.over, "Stepping into a hazard is a bump back to the start")
	game.lanes[7].cells.assign([4])
	game.lanes[7].dir = 1
	game.lanes[7].interval = 0.1
	game.lanes[7].clock = 0.0
	game.cat = Vector2i(5, 7)
	game.tick(0.1)
	expect(game.bumps == 2 and game.cat == Vector2i(5, 8), "A hazard rolling into the kitten is a bump too")
	game.lanes[7].cells.assign([5])
	game.turn(Vector2i.UP)
	expect(game.over and game.bumps == Dash.BUMPS, "Three bumps end the run")
	game.turn(Vector2i.LEFT)
	expect(game.cat == Vector2i(5, 8), "A finished run ignores moves")

	game = fresh()
	empty(game)
	for i in range(8):
		game.turn(Vector2i.UP)
	expect(game.crossings == 1 and game.score == 50 and game.cat == Vector2i(5, 8) and not game.lanes[1].cells.is_empty(), "Reaching the cushion scores and lays out a new floor")
	for i in range(20):
		game.turn(Vector2i.LEFT)
		game.turn(Vector2i.DOWN)
	expect(game.cat == Vector2i(0, 8), "The kitten stays inside the kitchen")
	var early: float = 0.0
	var late: float = 0.0
	for run in range(40):
		game = fresh(run)
		for row in game.lanes:
			early += game.lanes[row].interval
		game.crossings = 6
		game.lay_out()
		for row in game.lanes:
			late += game.lanes[row].interval
	expect(late < early * 0.75, "Later floors are faster")
	expect(fresh(42).lanes[1].cells == fresh(42).lanes[1].cells, "Seeded runs lay out identically")

	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var sound := true
	for run in range(100):
		game = fresh(run)
		for i in range(300):
			game.turn([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.UP, Vector2i.DOWN][dice.randi_range(0, 4)])
			game.tick(0.05)
			if game.over:
				break
			if game.cat.x < 0 or game.cat.y < 1 or game.cat.x >= Dash.WIDTH or game.cat.y >= Dash.HEIGHT:
				sound = false
			if game.lanes.has(game.cat.y) and game.lanes[game.cat.y].cells.has(game.cat.x):
				sound = false
	expect(sound, "Random play never leaves the kitten on a hazard or outside the kitchen")

	print("Kitchen dash rules: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
