extends RefCounted
## Shelf swat rules: keep a yarn ball in the air to knock everything off the shelves; three drops end the run.
## Positions are in cells, as fractions, with the origin at the top left.

const WIDTH := 13
const HEIGHT := 11
const DROPS := 3
const SHELVES := [1, 2, 3, 4]
const RADIUS := 0.3
const HALF := 1.3  # Half the cushion's width.
const CUSHION_Y := 10.0
const CUSHION_PACE := 9.0  # Cells per second while steering.

var cushion := WIDTH / 2.0
var ball := Vector2.ZERO
var velocity := Vector2.ZERO
var items := {}  # cell -> color
var score := 0
var knocked := 0
var level := 1
var drops := 0
var moving := false  # The ball rests on the cushion until the next turn serves it.
var over := false
var won := false  # Endless: kept so every side game reports the same outcome fields.
var paused := false
var rng := RandomNumberGenerator.new()


func start(seed_value: int) -> void:
	rng.seed = seed_value
	cushion = WIDTH / 2.0
	score = 0
	knocked = 0
	level = 1
	drops = 0
	moving = false
	over = false
	paused = false
	stock()
	rest()


func stock() -> void:
	items.clear()
	for y in SHELVES:
		for x in range(WIDTH):
			items[Vector2i(x, y)] = y % 3


func rest() -> void:
	ball = Vector2(cushion, CUSHION_Y - RADIUS)
	velocity = Vector2.ZERO


func speed() -> float:
	return minf(12.0, 5.5 + level + 0.06 * knocked)


func turn(direction: Vector2i) -> void:
	if over:
		return
	# A tap nudges the cushion, for on-screen buttons; holding a key steers smoothly in tick.
	cushion = clampf(cushion + direction.x * 0.75, HALF, WIDTH - HALF)
	if not moving:
		moving = true
		rest()
		velocity = Vector2(rng.randf_range(-0.5, 0.5), -1.0).normalized() * speed()


func tick(delta: float, steer: float = 0.0) -> void:
	if paused or over:
		return
	cushion = clampf(cushion + steer * CUSHION_PACE * delta, HALF, WIDTH - HALF)
	if not moving:
		rest()
		return
	# Small steps, so a fast ball cannot pass through an item or the cushion.
	var steps := ceili(speed() * delta / 0.2)
	for i in range(steps):
		if moving:
			step(delta / steps)


func step(delta: float) -> void:
	ball.x += velocity.x * delta
	if ball.x < RADIUS or ball.x > WIDTH - RADIUS:
		ball.x = clampf(ball.x, RADIUS, WIDTH - RADIUS)
		velocity.x = -velocity.x
	elif knock():
		velocity.x = -velocity.x
		ball.x += velocity.x * delta
	if not moving:
		return
	ball.y += velocity.y * delta
	if ball.y < RADIUS:
		ball.y = RADIUS
		velocity.y = -velocity.y
	elif knock():
		velocity.y = -velocity.y
		ball.y += velocity.y * delta
	if not moving:
		return
	if velocity.y > 0.0 and ball.y >= CUSHION_Y - RADIUS and ball.y < CUSHION_Y + 0.4 and absf(ball.x - cushion) <= HALF + RADIUS:
		# Where it lands on the cushion aims it; it always leaves steeply enough to return.
		velocity = Vector2((ball.x - cushion) / (HALF + RADIUS) * 0.85, -1.0).normalized() * speed()
		ball.y = CUSHION_Y - RADIUS
	elif ball.y > HEIGHT + RADIUS:
		drops += 1
		over = drops >= DROPS
		moving = false
		rest()


func knock() -> bool:
	if not items.erase(Vector2i(floori(ball.x), floori(ball.y))):
		return false
	knocked += 1
	score += 10
	if items.is_empty():
		level += 1
		score += 100
		stock()
		moving = false
		rest()
	return true
