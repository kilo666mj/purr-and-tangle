extends SceneTree

const Board = preload("res://scripts/board.gd")
const Session = preload("res://scripts/session.gd")
var assertions := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)


func settle(board: RefCounted) -> void:
	for i in range(1000):
		if board.phase in [Board.Phase.PLAYING, Board.Phase.WON, Board.Phase.LOST]:
			return
		board.resolve_step()
	expect(false, "Resolution must terminate")


func _initialize() -> void:
	var b := Board.new()
	for x in range(5):
		b.put(Vector2i(x, 12), b.piece(0, x == 0))
	for y in range(9, 16):
		b.put(Vector2i(2, y), b.piece(0, y == 9))
	expect(b.find_matches().size() == 11, "Long intersecting runs clear simultaneously without duplicates")
	b = Board.new()
	for i in range(4):
		b.put(Vector2i(i, i), b.piece(0))
	expect(b.find_matches().is_empty(), "Diagonals do not count")
	b = Board.new()
	b.put(Vector2i(2, 14), b.piece(0, false, 1))
	b.put(Vector2i(3, 14), b.piece(1, false, 1))
	b.put(Vector2i(2, 15), b.piece(2, true))
	expect(not b.gravity_step(), "One supported half holds the entire horizontal pair")
	b.matches = [Vector2i(2, 14)]
	b.clear_matches()
	expect(b.at(Vector2i(3, 14)).bond == 0, "Surviving cat loses its bond")
	expect(b.gravity_step() and b.at(Vector2i(3, 15)) != null, "Disconnected cat falls independently")
	expect(b.at(Vector2i(2, 15)).yarn, "Yarn remains fixed")
	b = Board.new()
	b.put(Vector2i(2, 5), b.piece(0, false, 2))
	b.put(Vector2i(2, 6), b.piece(1, false, 2))
	expect(b.gravity_step(), "Vertical pair can fall through its own previous position")
	expect(b.at(Vector2i(2, 6)).color == 0 and b.at(Vector2i(2, 7)).color == 1, "Vertical pair order and bond survive")
	b = Board.new()
	b.next_pair = [0, 1]
	b.spawn()
	b.active.anchor = Vector2i(7, 5)
	b.active.offset = Vector2i.DOWN
	expect(b.rotate(false), "Rotation kicks inward at the right wall")
	expect(b.fits(b.active.anchor, b.active.offset), "Rotated pair remains inside the board")
	var anchor: Vector2i = b.active.anchor
	for y in range(Board.HEIGHT):
		for x in range(Board.WIDTH):
			if not b.active_positions().has(Vector2i(x, y)):
				b.put(Vector2i(x, y), b.piece(2, true))
	expect(not b.rotate(false) and b.active.anchor == anchor, "Obstacle-blocked rotation is atomic")
	b = Board.new()
	b.next_pair = [0, 1]
	b.put(Vector2i(3, 0), b.piece(2, true))
	expect(not b.spawn() and b.phase == Board.Phase.LOST, "Blocked spawning ends the game")
	# Clear the final target while unrelated cats still occupy the spawn cells.
	b = Board.new()
	b.put(Vector2i(3, 0), b.piece(1))
	for y in range(Board.HEIGHT):
		b.put(Vector2i(4, y), b.piece(1 + y % 2))
	for x in range(4):
		b.put(Vector2i(x, 1), b.piece(0, x == 0))
	b.phase = Board.Phase.CHECKING
	settle(b)
	expect(b.at(Vector2i(4, 0)) != null, "Final-clear regression keeps spawning blocked")
	expect(b.phase == Board.Phase.WON, "Final target victory takes precedence over spawning")
	# A red row supports a blue cat above a fixed blue row of three.
	b = Board.new()
	for x in range(4):
		b.put(Vector2i(x, 14), b.piece(0, x == 0))
	for x in range(3):
		b.put(Vector2i(x, 15), b.piece(1, true))
	b.put(Vector2i(3, 13), b.piece(1))
	b.phase = Board.Phase.CHECKING
	settle(b)
	expect(b.phase == Board.Phase.WON and b.chain == 2, "Falling cats trigger a second clear and victory")
	expect(b.score == 800, "Chain multiplier applies once per simultaneously cleared cell")
	for seed_value in range(100):
		var a := Board.new()
		var c := Board.new()
		a.start(1 + seed_value % 20, seed_value)
		c.start(1 + seed_value % 20, seed_value)
		expect(a.cells == c.cells and a.next_pair == c.next_pair, "Seeded layouts and piece queues reproduce")
		expect(a.find_matches().is_empty(), "Generated boards contain no existing runs")
		expect(a.remaining_yarn() == mini(6 + a.level * 2, 52), "Level generator places every target")
	var session := Session.new()
	session.start()
	var before: Dictionary = session.board.active.duplicate(true)
	session.paused = true
	session.tick(100.0, true)
	session.action("drop")
	expect(session.board.active == before and session.fall_clock == 0.0, "Pause blocks timers and gameplay inputs")
	session.board.phase = Board.Phase.CLEARING
	session.tick(100.0)
	expect(session.board.phase == Board.Phase.CLEARING, "Pause freezes pending clear resolution")
	# Exercise connections and termination through varied legal input sequences.
	var random := RandomNumberGenerator.new()
	random.seed = 8128
	for run in range(12):
		b = Board.new()
		b.start(2, run)
		for turn in range(80):
			if b.phase != Board.Phase.PLAYING:
				break
			for attempt in range(random.randi_range(1, 10)):
				if random.randi_range(0, 1) == 0:
					b.move(Vector2i.LEFT if random.randi_range(0, 1) == 0 else Vector2i.RIGHT)
				else:
					b.rotate(random.randi_range(0, 1) == 0)
			b.hard_drop()
			settle(b)
			var bonds: Dictionary = {}
			for index in range(b.cells.size()):
				var cell: Variant = b.cells[index]
				if cell != null and cell.bond > 0:
					if not bonds.has(cell.bond):
						bonds[cell.bond] = []
					bonds[cell.bond].append(Vector2i(index % Board.WIDTH, int(index / float(Board.WIDTH))))
			for group in bonds.values():
				expect(group.size() == 2, "Every surviving bond has exactly two cats")
				if group.size() == 2:
					expect((group[0] - group[1]).length_squared() == 1, "Bonded cats remain adjacent")
			expect(b.find_matches().is_empty(), "Resolution leaves no outstanding matches")
	print("Rules: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
