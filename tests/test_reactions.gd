extends SceneTree

const Board = preload("res://scripts/board.gd")
const Companion = preload("res://scripts/cat_companion.gd")
var checks := 0
var failures := 0


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var board := Board.new()
	board.start(1, 1729)
	var companion := Companion.new()
	companion.reset(board)
	var cells := board.cells.duplicate(true)
	companion.advance(0.1, board, false)
	expect(companion.reaction == "idle", "Starting companion is calm")
	expect(board.cells == cells, "Companion cannot change board contents")
	board.hard_drop()
	companion.advance(0.1, board, false)
	expect(companion.reaction == "drop", "Landing a pair triggers a bounce")
	companion.advance(0.1, board, false)
	expect(companion.pose().stretch != Vector2.ONE, "Drop visibly changes the cat pose")
	var frozen: Dictionary = companion.pose()
	companion.advance(10.0, board, true)
	expect(companion.pose() == frozen, "Paused animation pose does not advance")
	board.chain = 1
	board.last_clear = [{"yarn": true}]
	companion.advance(0.1, board, false)
	expect(companion.reaction == "rescue", "Rescuing a kitten celebrates")
	board.chain = 2
	companion.advance(0.1, board, false)
	expect(companion.reaction == "chain", "A chain gets a bigger celebration")
	companion.advance(0.1, board, false)
	expect(companion.pose().offset.y < 0, "Celebration makes the cat hop")
	companion.reduced_motion = true
	var still := companion.pose()
	expect(still.offset == Vector2.ZERO and still.stretch == Vector2.ONE and still.angle == 0.0, "Reduced motion removes translation, scaling and rocking")
	expect(companion.reaction == "chain", "Reduced motion retains the reaction itself")
	board.put(Vector2i(0, 3), board.piece(0, false))
	companion.advance(2.0, board, false)
	expect(companion.reaction == "danger", "Crowding the top four rows worries the cat")
	board.put(Vector2i(0, 3), null)
	companion.advance(0.1, board, false)
	expect(companion.reaction == "idle", "Clearing the danger area calms the cat")
	board.phase = Board.Phase.LOST
	companion.advance(0.1, board, false)
	expect(companion.reaction == "lost", "Blocked basket shows the tangled reaction")
	board.start(1, 1729)
	companion.reset(board)
	expect(companion.reaction == "idle" and companion.elapsed == 0.0, "Restart clears the previous reaction")
	companion.free()
	print("Cat reactions: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
