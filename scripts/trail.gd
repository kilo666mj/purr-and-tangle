extends RefCounted
## Yarn trail rules: a kitten drags a growing strand of yarn and must not cross it.

const WIDTH := 17
const HEIGHT := 13

var cells: Array[Vector2i] = []  # Kitten first, then the strand behind it.
var colors: Array[int] = []  # Strand color per cell; index 0 (the kitten) is unused.
var heading := Vector2i.RIGHT
var turns: Array[Vector2i] = []  # Up to two queued turns, one taken per step.
var yarn := Vector2i.ZERO
var yarn_color := 0
var score := 0
var moving := false  # Waits for the first turn, so the player decides when to begin.
var over := false
var won := false
var paused := false
var clock := 0.0
var rng := RandomNumberGenerator.new()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	cells = [Vector2i(8, 6), Vector2i(7, 6), Vector2i(6, 6)]
	colors = [0, 0, 0]
	heading = Vector2i.RIGHT
	turns.clear()
	score = 0
	clock = 0.0
	moving = false
	over = false
	won = false
	paused = false
	place_yarn()


func turn(direction: Vector2i) -> void:
	# Quick presses queue up, one per step, so a fast up-then-left makes both turns.
	# Each is checked against the turn before it, so none can reverse into the strand.
	var last: Vector2i = heading if turns.is_empty() else turns.back()
	if over or direction == -last:
		return
	moving = true
	if direction != last and turns.size() < 2:
		turns.append(direction)


func interval() -> float:
	return maxf(0.08, 0.17 - 0.003 * (cells.size() - 3))


func tick(delta: float) -> void:
	if paused or over or not moving:
		return
	clock += delta
	while clock >= interval() and not over:
		clock -= interval()
		step()


func step() -> void:
	if not turns.is_empty():
		heading = turns.pop_front()
	var next := cells[0] + heading
	var grows := next == yarn
	# The strand's end moves away this step unless it grows, so following it is safe.
	var blocked := cells if grows else cells.slice(0, -1)
	if next.x < 0 or next.y < 0 or next.x >= WIDTH or next.y >= HEIGHT or blocked.has(next):
		over = true
		return
	cells.push_front(next)
	if grows:
		colors.append(yarn_color)
		score += 10
		place_yarn()
	else:
		cells.pop_back()


func place_yarn() -> void:
	var free: Array[Vector2i] = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if not cells.has(Vector2i(x, y)):
				free.append(Vector2i(x, y))
	if free.is_empty():
		won = true
		over = true
		return
	yarn = free[rng.randi_range(0, free.size() - 1)]
	yarn_color = rng.randi_range(0, 2)
