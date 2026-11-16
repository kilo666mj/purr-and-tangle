extends RefCounted
## Treat maze rules: eat every treat while two tangles give chase; three catches end the run.

const MAP := [
	"###############",
	"#......#......#",
	"#.##.#.#.#.##.#",
	"#.#..#...#..#.#",
	"#...##.#.##...#",
	"#.#....#....#.#",
	"#...##.#.##...#",
	"#.#..#...#..#.#",
	"#.##.#.#.#.##.#",
	"#......#......#",
	"###############",
]
const WIDTH := 15
const HEIGHT := 11
const CATCHES := 3
const CAT_START := Vector2i(1, 9)
const CHASER_STARTS := [Vector2i(13, 1), Vector2i(8, 3)]
const CAT_PACE := 0.15
const SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var cat := CAT_START
var heading := Vector2i.ZERO
var wanted := Vector2i.ZERO
var chasers: Array[Vector2i] = []
var chaser_headings: Array[Vector2i] = []
var treats := {}  # cell -> true
var score := 0
var level := 1
var catches := 0
var cat_clock := 0.0
var chaser_clock := 0.0
var moving := false  # The tangles wait for the first turn.
var over := false
var won := false  # Endless: kept so every side game reports the same outcome fields.
var paused := false
var rng := RandomNumberGenerator.new()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	score = 0
	level = 1
	catches = 0
	moving = false
	over = false
	paused = false
	fill()
	place()


func open(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < WIDTH and at.y < HEIGHT and MAP[at.y][at.x] != "#"


func fill() -> void:
	treats.clear()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if open(Vector2i(x, y)) and Vector2i(x, y) != CAT_START:
				treats[Vector2i(x, y)] = true


func place() -> void:
	cat = CAT_START
	heading = Vector2i.ZERO
	wanted = Vector2i.ZERO
	chasers.assign(CHASER_STARTS)
	chaser_headings.assign([Vector2i.ZERO, Vector2i.ZERO])
	cat_clock = 0.0
	chaser_clock = 0.0


func chaser_pace() -> float:
	return maxf(0.15, 0.26 - 0.02 * (level - 1))


func turn(direction: Vector2i) -> void:
	if over:
		return
	# Remembered until the next opening, so a turn can be pressed early.
	wanted = direction
	moving = true


func tick(delta: float) -> void:
	if paused or over or not moving:
		return
	cat_clock += delta
	chaser_clock += delta
	while cat_clock >= CAT_PACE and not over:
		cat_clock -= CAT_PACE
		step_cat()
	while chaser_clock >= chaser_pace() and not over:
		chaser_clock -= chaser_pace()
		step_chasers()


func step_cat() -> void:
	if open(cat + wanted):
		heading = wanted
	if not open(cat + heading):
		return
	cat += heading
	if chasers.has(cat):
		caught()
		return
	if treats.erase(cat):
		score += 10
		if treats.is_empty():
			level += 1
			score += 100
			fill()
			place()
			moving = false


func step_chasers() -> void:
	for i in range(chasers.size()):
		var options: Array[Vector2i] = []
		for side in SIDES:
			# No doubling back, so a tangle commits to a corridor and can be outrun.
			if side != -chaser_headings[i] and open(chasers[i] + side):
				options.append(side)
		if options.is_empty():
			options.append(-chaser_headings[i])
		var choice: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		# Mostly homes in on the kitten; the occasional wander keeps it escapable.
		if rng.randf() < 0.75:
			for side in options:
				if distance(chasers[i] + side) < distance(chasers[i] + choice):
					choice = side
		chaser_headings[i] = choice
		chasers[i] += choice
		if chasers[i] == cat:
			caught()
			return


func distance(at: Vector2i) -> int:
	return absi(at.x - cat.x) + absi(at.y - cat.y)


func caught() -> void:
	catches += 1
	over = catches >= CATCHES
	place()
	moving = false
