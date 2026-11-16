extends RefCounted
## Laser pounce rules: reach the red dot before it darts away; three escapes end the run.

const WIDTH := 9
const HEIGHT := 7
const ESCAPES := 3

var cat := Vector2i.ZERO
var dot := Vector2i.ZERO
var time_left := 0.0
var time_total := 0.0
var score := 0
var pounces := 0
var misses := 0
var moving := false  # The dot waits for the first move, so the player decides when to begin.
var over := false
var won := false  # Endless: kept so every side game reports the same outcome fields.
var paused := false
var rng := RandomNumberGenerator.new()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	cat = Vector2i(WIDTH / 2, HEIGHT / 2)
	score = 0
	pounces = 0
	misses = 0
	moving = false
	over = false
	paused = false
	place_dot()


func pace() -> float:
	# Seconds allowed per cell of distance; shrinks with every pounce.
	return maxf(0.14, 0.32 - 0.006 * pounces)


func turn(direction: Vector2i) -> void:
	if over:
		return
	moving = true
	cat = (cat + direction).clamp(Vector2i.ZERO, Vector2i(WIDTH - 1, HEIGHT - 1))
	if cat == dot:
		pounces += 1
		# A quicker pounce earns up to double.
		score += 10 + roundi(10.0 * time_left / time_total)
		place_dot()


func tick(delta: float) -> void:
	if paused or over or not moving:
		return
	time_left -= delta
	if time_left <= 0.0:
		misses += 1
		if misses >= ESCAPES:
			over = true
		else:
			place_dot()


func place_dot() -> void:
	# Far enough away that a pounce is never free; time scales with distance, so any spot is fair.
	var far: Array[Vector2i] = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if absi(x - cat.x) + absi(y - cat.y) >= 3:
				far.append(Vector2i(x, y))
	dot = far[rng.randi_range(0, far.size() - 1)]
	time_total = 0.6 + (absi(dot.x - cat.x) + absi(dot.y - cat.y)) * pace()
	time_left = time_total
