extends SceneTree

const Trail = preload("res://scripts/trail.gd")

var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh(seed_value: int = 7) -> RefCounted:
	var trail := Trail.new()
	trail.start(seed_value)
	return trail


func _initialize() -> void:
	var trail := fresh()
	expect(trail.cells.size() == 3 and not trail.cells.has(trail.yarn), "A run starts short with yarn off the strand")
	trail.tick(5.0)
	expect(trail.cells[0] == Vector2i(8, 6), "The kitten waits for the first turn")
	trail.turn(Vector2i.LEFT)
	expect(not trail.moving, "Reversing into the strand is ignored")
	trail.yarn = Vector2i(0, 0)
	trail.turn(Vector2i.UP)
	trail.paused = true
	trail.tick(5.0)
	expect(trail.cells[0] == Vector2i(8, 6), "Pause freezes the kitten")
	trail.paused = false
	trail.tick(trail.interval())
	expect(trail.cells[0] == Vector2i(8, 5) and trail.cells.size() == 3, "A step moves the kitten without growing")
	trail.turn(Vector2i.DOWN)
	expect(trail.turns.is_empty(), "The kitten cannot reverse while moving")
	trail.turn(Vector2i.LEFT)
	trail.turn(Vector2i.DOWN)
	trail.turn(Vector2i.RIGHT)
	expect(trail.turns == [Vector2i.LEFT, Vector2i.DOWN], "Two quick turns are both kept; a third waits its turn")
	trail.turn(Vector2i.UP)
	expect(trail.turns.size() == 2, "A queued turn cannot be reversed either")
	trail.step()
	trail.step()
	expect(trail.cells[0] == Vector2i(7, 6) and not trail.over, "Quick turns happen one step at a time")

	trail = fresh()
	trail.yarn = Vector2i(9, 6)
	trail.turn(Vector2i.RIGHT)
	trail.step()
	expect(trail.cells.size() == 4 and trail.score == 10 and trail.colors.size() == 4, "Collecting yarn grows the strand and scores")
	expect(not trail.cells.has(trail.yarn), "New yarn never lands on the strand")
	expect(trail.interval() < fresh().interval(), "A longer strand moves faster")
	trail.cells.resize(200)
	expect(is_equal_approx(trail.interval(), 0.08), "Speed has a floor")

	trail = fresh()
	trail.yarn = Vector2i(0, 0)
	trail.turn(Vector2i.RIGHT)
	for i in range(8):
		trail.step()
	expect(not trail.over and trail.cells[0].x == Trail.WIDTH - 1, "The kitten can reach the basket edge")
	trail.step()
	expect(trail.over and not trail.won, "Leaving the basket ends the run")
	trail.turn(Vector2i.UP)
	expect(trail.turns.is_empty(), "A finished run ignores turns")

	trail = fresh()
	trail.yarn = Vector2i(0, 0)
	trail.cells.assign([Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 6)])
	trail.turn(Vector2i.DOWN)
	trail.step()
	expect(not trail.over, "Following the end of the strand is safe")
	trail = fresh()
	trail.yarn = Vector2i(0, 0)
	trail.cells.assign([Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)])
	trail.colors.assign([0, 0, 0, 0, 0])
	trail.turn(Vector2i.DOWN)
	trail.step()
	expect(trail.over, "Crossing the strand ends the run")

	trail = fresh()
	trail.cells.clear()
	for y in range(Trail.HEIGHT):
		for x in range(Trail.WIDTH):
			trail.cells.append(Vector2i(x, y))
	trail.place_yarn()
	expect(trail.won and trail.over, "Filling the basket wins")

	var first := fresh(42)
	var second := fresh(42)
	expect(first.yarn == second.yarn and first.yarn_color == second.yarn_color, "Seeded runs place yarn identically")

	# Random play must never corrupt the strand, whatever the player does.
	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var sound := true
	for run in range(200):
		trail = fresh(run)
		for i in range(300):
			if trail.over:
				break
			trail.turn([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][dice.randi_range(0, 3)])
			trail.step()
			var seen := {}
			for cell in trail.cells:
				if seen.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= Trail.WIDTH or cell.y >= Trail.HEIGHT:
					sound = false
				seen[cell] = true
			if trail.cells.has(trail.yarn) or trail.colors.size() != trail.cells.size():
				sound = false
	expect(sound, "Random play keeps the strand in bounds, unbroken and clear of the yarn")

	print("Yarn trail rules: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
