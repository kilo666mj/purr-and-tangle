class_name PuzzleSession
extends RefCounted

const Board = preload("res://scripts/board.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
var difficulty := Difficulty.NORMAL
var board := Board.new()
var paused := false
var fall_clock := 0.0
var lock_clock := 0.0
var resolve_clock := 0.0
var lock_resets := 0
var run_seed := 1729
var play_time := 0.0


func start(level: int = 1, carried_score: int = 0) -> void:
	board.start(level, run_seed + level * 104729, carried_score, difficulty)
	paused = false
	play_time = 0.0
	reset_clocks()


func reset_clocks() -> void:
	fall_clock = 0.0
	lock_clock = 0.0
	resolve_clock = 0.0
	lock_resets = 0


func action(name: String) -> void:
	if paused or board.phase != Board.Phase.PLAYING:
		return
	var moved := false
	match name:
		"left": moved = board.move(Vector2i.LEFT)
		"right": moved = board.move(Vector2i.RIGHT)
		"rotate": moved = board.rotate()
		"reverse": moved = board.rotate(false)
		"drop": board.hard_drop()
	if moved and lock_resets < 8:
		lock_clock = 0.0
		lock_resets += 1


func fall_interval() -> float:
	return Difficulty.fall_interval(difficulty, board.level, play_time)


func tick(delta: float, soft_drop: bool = false, shared_play_time: float = -1.0) -> void:
	if paused or board.phase in [Board.Phase.WON, Board.Phase.LOST]:
		return
	# Resolution time counts too. Piece/chain clock resets must not reset pace.
	play_time = shared_play_time if shared_play_time >= 0.0 else play_time + delta
	if board.phase == Board.Phase.PLAYING:
		var interval := fall_interval()
		if soft_drop:
			interval = 0.055
		fall_clock += delta
		if fall_clock >= interval:
			fall_clock = 0.0
			if board.move(Vector2i.DOWN):
				if soft_drop:
					board.score += 1
				lock_clock = 0.0
				lock_resets = 0
		if not board.active.is_empty() and not board.fits(board.active.anchor + Vector2i.DOWN, board.active.offset):
			lock_clock += delta
			if lock_clock >= 0.35:
				board.lock_pair()
				reset_clocks()
	else:
		resolve_clock += delta
		var interval := 0.26 if board.phase == Board.Phase.CLEARING else 0.065
		if resolve_clock >= interval:
			resolve_clock = 0.0
			board.resolve_step()
			if board.phase == Board.Phase.PLAYING:
				reset_clocks()
