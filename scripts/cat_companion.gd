extends "res://scripts/puzzle_art.gd"
## Presentation-only reactions. Pausing freezes the clock; no gameplay writes.

const Board = preload("res://scripts/board.gd")
var reduced_motion := false
var reaction := "idle"
var reaction_age := 0.0
var reaction_duration := 0.0
var elapsed := 0.0
var crowded := false
var previous_pair := 0
var previous_chain := 0
var previous_phase := Board.Phase.PLAYING


func reset(board: RefCounted) -> void:
	reaction = "idle"
	reaction_age = 0.0
	reaction_duration = 0.0
	elapsed = 0.0
	crowded = false
	previous_pair = board.pair_serial
	previous_chain = board.chain
	previous_phase = board.phase
	queue_redraw()


func react(kind: String, duration: float) -> void:
	reaction = kind
	reaction_age = 0.0
	reaction_duration = duration


func advance(delta: float, board: RefCounted, paused: bool) -> void:
	if paused:
		return
	elapsed += delta
	reaction_age += delta
	crowded = false
	for y in range(4):
		for x in range(Board.WIDTH):
			if board.at(Vector2i(x, y)) != null:
				crowded = true
	if reaction_age >= reaction_duration:
		reaction = "danger" if crowded else "idle"
	if board.pair_serial != previous_pair:
		react("drop", 0.45)
	if board.chain > previous_chain:
		var rescued := false
		for cell in board.last_clear:
			rescued = rescued or cell.yarn
		react("chain" if board.chain > 1 else ("rescue" if rescued else "clear"), 1.5)
	if board.phase != previous_phase:
		if board.phase == Board.Phase.WON:
			react("won", 2.0)
		elif board.phase == Board.Phase.LOST:
			react("lost", 2.0)
	previous_pair = board.pair_serial
	previous_chain = board.chain
	previous_phase = board.phase
	queue_redraw()


func pose() -> Dictionary:
	var offset := Vector2.ZERO
	var stretch := Vector2.ONE
	var angle := 0.0
	if not reduced_motion:
		stretch.y += sin(elapsed * 2.4) * 0.012
		var t := clampf(reaction_age / maxf(reaction_duration, 0.01), 0.0, 1.0)
		if reaction == "drop":
			var squash := sin(t * PI) * (1.0 - t)
			stretch += Vector2(0.12, -0.10) * squash
		elif reaction in ["clear", "rescue", "chain", "won"]:
			offset.y = -absf(sin(t * TAU)) * (26.0 if reaction == "chain" else 17.0) * (1.0 - t)
			angle = sin(t * TAU * 2.0) * 0.08 * (1.0 - t)
		elif reaction in ["danger", "lost"]:
			angle = sin(elapsed * 5.0) * 0.025
	return {"offset": offset, "stretch": stretch, "angle": angle}


func _draw() -> void:
	var happy := reaction in ["rescue", "chain", "won"]
	var key := "cat_won" if reaction == "won" else "cat_success" if happy else ("cat_failure" if reaction == "lost" else "cat_orange")
	if not textures.has(key):
		return
	var motion := pose()
	draw_set_transform(Vector2(112.5, 215) + motion.offset, motion.angle, motion.stretch)
	draw_texture_rect(textures[key], Rect2(-112.5, -215, 225, 225), false)
	draw_set_transform(Vector2.ZERO)
	if reaction in ["clear", "rescue", "chain", "won"]:
		var rise := 0.0 if reduced_motion else reaction_age * 14.0
		text_at("♥", Vector2(18, 50 - rise), 26, Color("ba6f60"))
		text_at("♥", Vector2(188, 73 - rise), 19, Color("ba6f60"))
	elif reaction == "danger":
		text_at("!", Vector2(193, 38), 29, Color("a66d3f"))
