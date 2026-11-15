extends SceneTree

const MatchState = preload("res://scripts/versus_match.gd")
const Inputs = preload("res://scripts/versus_input.gd")
const Board = preload("res://scripts/board.gd")
const Session = preload("res://scripts/session.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func button(device: int, index: int, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	return event


func key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _initialize() -> void:
	for preset in [Difficulty.RELAXED, Difficulty.NORMAL, Difficulty.SPICY]:
		for level in [1, 2, 10, 30]:
			var game := Session.new()
			game.difficulty = preset
			game.start(level)
			var expected_targets: int = mini([4, 8, 12][preset] + (level - 1) * 2, 52)
			expect(game.board.remaining_yarn() == expected_targets, "Each difficulty generates its target count, capped at 52")
			expect(game.board.find_matches().is_empty(), "Difficulty layouts have no automatic matches")
			game.tick(0.18)
			expect(game.board.active.anchor.y == (1 if level == 30 else 0), "All difficulties reach the same maximum speed")
		var race_preset := MatchState.new()
		race_preset.reset(1729, preset)
		expect(race_preset.players[0].difficulty == preset and race_preset.players[1].difficulty == preset, "Both versus players share the selected difficulty")
		race_preset.next_round()
		expect(race_preset.difficulty == preset and race_preset.players[1].difficulty == preset, "Difficulty is preserved across rematches")
		expect(race_preset.players[0].board.cells == race_preset.players[1].board.cells, "All presets generate fair rematches")
		var slow := Session.new()
		slow.difficulty = preset
		slow.start()
		slow.tick(0.70)
		expect(slow.board.active.anchor.y == (1 if preset == Difficulty.SPICY else 0), "Spicy starts faster than Normal and Relaxed")
		slow.start()
		slow.tick(0.90)
		expect(slow.board.active.anchor.y == (0 if preset == Difficulty.RELAXED else 1), "Relaxed starts slower than Normal and Spicy")
	expect(Difficulty.valid(-1) == Difficulty.NORMAL and Difficulty.valid(99) == Difficulty.NORMAL, "Invalid saved preset falls back to Normal")
	for seed_value in range(20):
		var race := MatchState.new()
		race.reset(seed_value)
		expect(race.players[0].board.cells == race.players[1].board.cells, "Both players get identical yarn layouts")
		expect(race.players[0].board != race.players[1].board, "Boards are independently mutable")
		var pairs: Array = []
		for i in range(60):
			pairs.append(race.players[0].board.next_pair.duplicate())
			race.players[0].board.spawn()
		for i in range(60):
			expect(race.players[1].board.next_pair == pairs[i], "Piece sequence stays fair when one player plays faster")
			race.players[1].board.spawn()
	var race := MatchState.new()
	race.reset(1729)
	race.tick(10)
	expect(race.countdown == 3.0, "Lobby freezes countdown")
	race.set_paused(false)
	race.action(0, "drop")
	expect(not race.players[0].board.active.is_empty(), "Countdown ignores actions")
	race.tick(2.0)
	expect(race.players[0].board.active.anchor.y == 0 and race.players[1].board.active.anchor.y == 0, "Countdown freezes both pieces")
	race.set_paused(true)
	race.tick(10)
	expect(race.countdown == 1.0, "Pause freezes countdown")
	race.set_paused(false)
	race.tick(1.0)
	race.action(0, "left")
	expect(race.players[0].board.active.anchor.x == 2 and race.players[1].board.active.anchor.x == 3, "Actions affect only their player")
	race.tick(0.81)
	expect(race.players[0].board.active.anchor.y == 0 and race.players[1].board.active.anchor.y == 0, "Round 1 has the same speed on both boards")
	race.set_paused(true)
	race.action(1, "drop")
	race.tick(10, [true, true])
	expect(not race.players[1].board.active.is_empty() and race.players[1].board.active.anchor.y == 0, "Pause blocks both actions and soft drops")
	race.next_round()
	expect(race.round_number == 2 and race.players[0].board.level == 2 and race.players[1].board.level == 2, "Rematch advances both to the same level")
	expect(race.players[0].board.remaining_yarn() == 10 and race.players[0].board.cells == race.players[1].board.cells, "Next round has more yarn and identical layouts")
	race.set_paused(false)
	race.tick(3)
	race.tick(0.81)
	expect(race.players[0].board.active.anchor.y == 1 and race.players[1].board.active.anchor.y == 1, "Round 2 falls faster for both players")
	var fast := Session.new()
	fast.start(100)
	fast.tick(0.17)
	expect(fast.board.active.anchor.y == 0, "Fall speed is capped at 180 ms")
	fast.tick(0.011)
	expect(fast.board.active.anchor.y == 1, "Capped fall speed still advances")
	# Outcomes are considered together, so update order cannot break a tie.
	for phases in [[Board.Phase.WON, Board.Phase.PLAYING, MatchState.Result.PLAYER_ONE], [Board.Phase.PLAYING, Board.Phase.WON, MatchState.Result.PLAYER_TWO], [Board.Phase.LOST, Board.Phase.PLAYING, MatchState.Result.PLAYER_TWO], [Board.Phase.PLAYING, Board.Phase.LOST, MatchState.Result.PLAYER_ONE], [Board.Phase.WON, Board.Phase.WON, MatchState.Result.DRAW], [Board.Phase.LOST, Board.Phase.LOST, MatchState.Result.DRAW]]:
		race.reset(1729)
		race.set_paused(false)
		race.countdown = 0.0
		race.players[0].board.phase = phases[0]
		race.players[1].board.phase = phases[1]
		race.tick(0)
		expect(race.result == phases[2] and race.paused, "Clear/top-out/tie freezes both boards and decides correct outcome")
		var wins: Array = race.wins.duplicate()
		race.tick(10)
		expect(race.wins == wins, "Winner is counted once")
		race.next_round()
		expect(race.wins == wins and race.result == MatchState.Result.PLAYING, "Rematch keeps wins and resets result")
	var inputs := Inputs.new()
	expect(inputs.join(2) == 0 and inputs.join(2) == 0 and not inputs.ready(), "One pad cannot fill both player slots")
	expect(inputs.join(7) == 1 and inputs.ready(), "Nonconsecutive device IDs work")
	expect(inputs.join(9) == -1, "Third controller cannot steal a slot")
	inputs.handle(button(2, JOY_BUTTON_A))
	expect(inputs.poll(0, 0).actions == ["rotate"] and inputs.poll(1, 0).actions.is_empty(), "Face buttons route to assigned player")
	inputs.handle(button(2, JOY_BUTTON_A))
	expect(inputs.poll(0, 0).actions.is_empty(), "Holding a face button does not repeat rotation")
	inputs.handle(button(2, JOY_BUTTON_A, false))
	inputs.handle(button(7, JOY_BUTTON_X))
	expect(inputs.poll(1, 0).actions == ["drop"] and inputs.poll(0, 0).actions.is_empty(), "Second player hard-drop is independent")
	inputs.handle(button(9, JOY_BUTTON_X))
	expect(inputs.poll(0, 0).actions.is_empty() and inputs.poll(1, 0).actions.is_empty(), "Unassigned pad is ignored")
	inputs.handle(button(2, JOY_BUTTON_DPAD_LEFT))
	expect(inputs.poll(0, 0).actions == ["left"], "Move starts immediately")
	expect(inputs.poll(0, 0.19).actions.is_empty(), "Move has a deliberate initial repeat delay")
	expect(inputs.poll(0, 0.02).actions == ["left"], "Held movement repeats after delay")
	var axis := InputEventJoypadMotion.new()
	axis.device = 7
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.3
	inputs.handle(axis)
	expect(inputs.poll(1, 0).actions.is_empty(), "Analog deadzone rejects drift")
	axis.axis_value = 0.8
	inputs.handle(axis)
	expect(inputs.poll(1, 0).actions == ["right"], "Stick routes to second player")
	expect(inputs.remove_device(9) == -1 and inputs.ready(), "Unassigned disconnect leaves assignments intact")
	expect(inputs.remove_device(2) == 0 and not inputs.ready(), "Assigned disconnect vacates only its slot")
	expect(inputs.poll(0, 10).actions.is_empty() and inputs.poll(1, 10).actions.is_empty(), "Disconnect clears held inputs on both players")
	expect(inputs.join(5) == 0 and inputs.devices == [5, 7], "Replacement controller fills vacant slot")
	inputs.keyboard(0)
	inputs.handle(key(KEY_A))
	inputs.handle(button(7, JOY_BUTTON_A, false))
	inputs.handle(button(7, JOY_BUTTON_A))
	expect(inputs.poll(0, 0).actions == ["left"] and inputs.poll(1, 0).actions == ["rotate"], "Keyboard plus controller can play together")
	inputs.keyboard(1)
	inputs.handle(key(KEY_E))
	inputs.handle(key(KEY_UP))
	expect(inputs.poll(0, 0).actions == ["drop"] and inputs.poll(1, 0).actions == ["rotate"], "Shared keyboard routes separate controls")
	inputs.handle(key(KEY_DOWN))
	expect(not inputs.poll(0, 0).soft and inputs.poll(1, 0).soft, "Soft drop is independent")
	inputs.clear()
	expect(not inputs.poll(1, 0).soft and inputs.ready(), "Clearing held keys preserves assignments")
	print("Versus rules/input: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
