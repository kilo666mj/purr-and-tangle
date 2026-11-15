extends RefCounted
## Local race. Resolve both players before deciding an outcome for this frame.

const Session = preload("res://scripts/session.gd")
const Board = preload("res://scripts/board.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
enum Result { PLAYING, PLAYER_ONE, PLAYER_TWO, DRAW }

var players: Array = [Session.new(), Session.new()]
var result := Result.PLAYING
var wins: Array = [0, 0]
var round_number := 1
var run_seed := 1729
var paused := true
var countdown := 3.0
var difficulty := Difficulty.NORMAL
var play_time := 0.0


func reset(seed_value: int, preset: int = Difficulty.NORMAL) -> void:
	run_seed = seed_value
	difficulty = Difficulty.valid(preset)
	round_number = 1
	wins = [0, 0]
	prepare_round()


func prepare_round() -> void:
	result = Result.PLAYING
	countdown = 3.0
	play_time = 0.0
	for player in players:
		player.run_seed = run_seed
		player.difficulty = difficulty
		player.start(round_number)
	set_paused(true)


func next_round() -> void:
	round_number += 1
	prepare_round()


func set_paused(value: bool) -> void:
	paused = value
	for player in players:
		player.paused = value or result != Result.PLAYING


func action(player: int, name: String) -> void:
	if paused or countdown > 0.0 or result != Result.PLAYING or player < 0 or player > 1:
		return
	players[player].action(name)


func tick(delta: float, soft_drop: Array = [false, false]) -> void:
	if paused or result != Result.PLAYING:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		return
	play_time += delta
	for i in range(2):
		players[i].tick(delta, soft_drop[i], play_time)
	var first: int = players[0].board.phase
	var second: int = players[1].board.phase
	if (first == Board.Phase.WON and second == Board.Phase.WON) or (first == Board.Phase.LOST and second == Board.Phase.LOST):
		result = Result.DRAW
	elif first == Board.Phase.WON or second == Board.Phase.LOST:
		result = Result.PLAYER_ONE
	elif second == Board.Phase.WON or first == Board.Phase.LOST:
		result = Result.PLAYER_TWO
	if result != Result.PLAYING:
		if result != Result.DRAW:
			wins[result - 1] += 1
		set_paused(true)
