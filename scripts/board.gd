class_name PuzzleBoard
extends RefCounted
## Pure deterministic rules. Drawing, input and timing belong to the session/UI.

const WIDTH := 8
const HEIGHT := 16
const Difficulty = preload("res://scripts/difficulty.gd")
enum Phase { PLAYING, CHECKING, CLEARING, GRAVITY, WON, LOST }

var cells: Array = []
var active: Dictionary = {}
var next_pair: Array = []
var matches: Array = []
var phase := Phase.PLAYING
var level := 1
var score := 0
var chain := 0
var rescued := 0
var last_clear: Array = []
var pair_serial := 0
var piece_serial := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	cells.resize(WIDTH * HEIGHT)
	cells.fill(null)


func start(new_level: int, puzzle_seed: int, carried_score: int = 0, difficulty: int = Difficulty.NORMAL) -> void:
	cells.fill(null)
	active = {}
	matches = []
	last_clear = []
	level = new_level
	score = carried_score
	chain = 0
	rescued = 0
	pair_serial = 0
	piece_serial = 0
	rng.seed = puzzle_seed
	var target_count := Difficulty.targets(difficulty, level)
	var top_row := maxi(5, 11 - int(level / 2.0))
	var placed := 0
	var attempts := 0
	while placed < target_count and attempts < 10000:
		attempts += 1
		var pos := Vector2i(rng.randi_range(0, WIDTH - 1), rng.randi_range(top_row, HEIGHT - 1))
		if at(pos) != null:
			continue
		put(pos, piece(rng.randi_range(0, 2), true))
		if find_matches().is_empty():
			placed += 1
		else:
			put(pos, null)
	next_pair = random_pair()
	spawn()


func piece(color: int, yarn: bool = false, bond: int = 0) -> Dictionary:
	piece_serial += 1
	return {"color": color, "yarn": yarn, "bond": bond, "uid": piece_serial}


func inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < WIDTH and pos.y >= 0 and pos.y < HEIGHT


func at(pos: Vector2i) -> Variant:
	if not inside(pos):
		return null
	return cells[pos.y * WIDTH + pos.x]


func put(pos: Vector2i, value: Variant) -> void:
	assert(inside(pos))
	cells[pos.y * WIDTH + pos.x] = value


func random_pair() -> Array:
	return [rng.randi_range(0, 2), rng.randi_range(0, 2)]


func fits(anchor: Vector2i, offset: Vector2i) -> bool:
	for pos in [anchor, anchor + offset]:
		if not inside(pos) or at(pos) != null:
			return false
	return true


func spawn() -> bool:
	if not fits(Vector2i(3, 0), Vector2i.RIGHT):
		phase = Phase.LOST
		active = {}
		return false
	active = {"anchor": Vector2i(3, 0), "offset": Vector2i.RIGHT, "colors": next_pair.duplicate()}
	next_pair = random_pair()
	phase = Phase.PLAYING
	chain = 0
	return true


func active_positions() -> Array:
	if active.is_empty():
		return []
	return [active.anchor, active.anchor + active.offset]


func move(direction: Vector2i) -> bool:
	if phase != Phase.PLAYING or active.is_empty():
		return false
	var anchor: Vector2i = active.anchor + direction
	if not fits(anchor, active.offset):
		return false
	active.anchor = anchor
	return true


func rotate(clockwise: bool = true) -> bool:
	if phase != Phase.PLAYING or active.is_empty():
		return false
	var offset: Vector2i = active.offset
	offset = Vector2i(-offset.y, offset.x) if clockwise else Vector2i(offset.y, -offset.x)
	# Small, deterministic wall/floor/top kicks. Never tunnel through an obstacle.
	for kick in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var anchor: Vector2i = active.anchor + kick
		if fits(anchor, offset):
			active.anchor = anchor
			active.offset = offset
			return true
	return false


func ghost_positions() -> Array:
	if active.is_empty():
		return []
	var anchor: Vector2i = active.anchor
	while fits(anchor + Vector2i.DOWN, active.offset):
		anchor += Vector2i.DOWN
	return [anchor, anchor + active.offset]


func hard_drop() -> void:
	if phase != Phase.PLAYING:
		return
	while move(Vector2i.DOWN):
		score += 2
	lock_pair()


func lock_pair() -> void:
	if phase != Phase.PLAYING or active.is_empty():
		return
	pair_serial += 1
	var positions := active_positions()
	for i in range(2):
		put(positions[i], piece(active.colors[i], false, pair_serial))
	active = {}
	phase = Phase.CHECKING
	chain = 0


func find_matches() -> Array:
	var found: Dictionary = {}
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var start := Vector2i(x, y)
			var cell: Variant = at(start)
			if cell == null:
				continue
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var previous: Variant = at(start - direction)
				if previous != null and previous.color == cell.color:
					continue
				var run: Array = []
				var pos: Vector2i = start
				while inside(pos) and at(pos) != null and at(pos).color == cell.color:
					run.append(pos)
					pos += direction
				if run.size() >= 4:
					for matched in run:
						found[matched] = true
	return found.keys()


func clear_matches() -> void:
	last_clear = []
	chain += 1
	for pos in matches:
		var cell: Variant = at(pos)
		if cell == null:
			continue
		last_clear.append({"pos": pos, "color": cell.color, "yarn": cell.yarn})
		score += (100 if cell.yarn else 20) * chain
		if cell.yarn:
			rescued += 1
		put(pos, null)
	# Split pairs whose other member has cleared, preserving every intact pair.
	var bonds: Dictionary = {}
	for cell in cells:
		if cell != null and cell.bond > 0:
			bonds[cell.bond] = bonds.get(cell.bond, 0) + 1
	for cell in cells:
		if cell != null and cell.bond > 0 and bonds[cell.bond] == 1:
			cell.bond = 0
	matches = []


func gravity_step() -> bool:
	var groups: Array = []
	var seen: Dictionary = {}
	# Snapshot groups bottom first so each group moves at most one row per step.
	for index in range(cells.size() - 1, -1, -1):
		var cell: Variant = cells[index]
		if cell == null or cell.yarn:
			continue
		var pos := Vector2i(index % WIDTH, int(index / float(WIDTH)))
		if cell.bond == 0:
			groups.append([pos])
		elif not seen.has(cell.bond):
			seen[cell.bond] = true
			var group: Array = []
			for other in range(cells.size()):
				if cells[other] != null and cells[other].bond == cell.bond:
					group.append(Vector2i(other % WIDTH, int(other / float(WIDTH))))
			groups.append(group)
	var moved := false
	for group in groups:
		var can_fall := true
		for pos in group:
			var target: Vector2i = pos + Vector2i.DOWN
			if not inside(target) or (at(target) != null and not group.has(target)):
				can_fall = false
		if not can_fall:
			continue
		var saved: Array = []
		for pos in group:
			saved.append(at(pos))
			put(pos, null)
		for i in range(group.size()):
			put(group[i] + Vector2i.DOWN, saved[i])
		moved = true
	return moved


func remaining_yarn() -> int:
	var count := 0
	for cell in cells:
		if cell != null and cell.yarn:
			count += 1
	return count


func resolve_step() -> void:
	match phase:
		Phase.CHECKING:
			matches = find_matches()
			if not matches.is_empty():
				phase = Phase.CLEARING
			elif remaining_yarn() == 0:
				phase = Phase.WON
			else:
				spawn()
		Phase.CLEARING:
			clear_matches()
			phase = Phase.GRAVITY
		Phase.GRAVITY:
			if not gravity_step():
				phase = Phase.CHECKING
