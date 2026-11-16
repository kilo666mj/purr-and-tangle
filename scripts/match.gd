extends RefCounted
## Kitten match rules: flip two cards at a time to pair them all before running out of misses.

const WIDTH := 6
const HEIGHT := 4
const MISSES := 14
const PEEK := 0.9  # Seconds a mismatched pair stays face up.

var cursor := Vector2i.ZERO
var faces: Array[int] = []  # 12 kinds, two cards each.
var matched: Array[bool] = []
var picked: Array[int] = []  # Face-up, unmatched card indexes: at most two.
var peek := 0.0
var score := 0
var pairs := 0
var misses := 0
var moving := false
var over := false
var won := false
var paused := false
var rng := RandomNumberGenerator.new()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	cursor = Vector2i.ZERO
	faces.clear()
	matched.clear()
	picked.clear()
	for i in range(WIDTH * HEIGHT):
		faces.append(i / 2)
		matched.append(false)
	# Fisher-Yates with the seeded generator, so a run can be reproduced.
	for i in range(faces.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var kept := faces[i]
		faces[i] = faces[j]
		faces[j] = kept
	peek = 0.0
	score = 0
	pairs = 0
	misses = 0
	moving = false
	over = false
	won = false
	paused = false


func turn(direction: Vector2i) -> void:
	if over:
		return
	moving = true
	cursor = (cursor + direction).clamp(Vector2i.ZERO, Vector2i(WIDTH - 1, HEIGHT - 1))


func shown(index: int) -> bool:
	return matched[index] or picked.has(index)


func act() -> void:
	if over:
		return
	moving = true
	# Flipping again dismisses a mismatched pair early.
	if picked.size() == 2:
		picked.clear()
	var index := cursor.y * WIDTH + cursor.x
	if shown(index):
		return
	picked.append(index)
	if picked.size() < 2:
		return
	if faces[picked[0]] == faces[picked[1]]:
		matched[picked[0]] = true
		matched[picked[1]] = true
		picked.clear()
		pairs += 1
		score += 20
		if pairs * 2 == faces.size():
			# Unused misses are worth a bonus.
			score += 10 * (MISSES - misses)
			won = true
			over = true
	else:
		misses += 1
		peek = PEEK
		over = misses >= MISSES


func tick(delta: float) -> void:
	if paused or over or picked.size() < 2:
		return
	peek -= delta
	if peek <= 0.0:
		picked.clear()
