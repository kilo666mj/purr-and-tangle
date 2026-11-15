extends SceneTree

const Session = preload("res://scripts/session.gd")
const MatchState = preload("res://scripts/versus_match.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const Board = preload("res://scripts/board.gd")
const Art = preload("res://scripts/puzzle_art.gd")
var checks := 0
var failures := 0


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _initialize() -> void:
	for preset in [Difficulty.RELAXED, Difficulty.NORMAL, Difficulty.SPICY]:
		var player := Session.new()
		player.difficulty = preset
		player.start()
		var initial := player.fall_interval()
		player.tick(19.0)
		expect(is_equal_approx(player.fall_interval(), initial), "Each preset holds its initial pace before 20 seconds")
		player.tick(1.0)
		expect(is_equal_approx(player.fall_interval(), initial * 0.85), "All presets accelerate at 20 seconds")
		player.tick(20.0)
		expect(is_equal_approx(player.fall_interval(), initial * 0.85 * 0.85), "A second speed increase happens at 40 seconds")
		player.paused = true
		player.tick(100.0, true)
		expect(player.play_time == 40.0, "Pausing freezes the speed ramp even with soft drop held")
		player.paused = false
		player.reset_clocks()
		expect(player.play_time == 40.0, "Resetting piece timers preserves elapsed basket time")
		player.action("drop")
		player.tick(0.1)
		expect(is_equal_approx(player.play_time, 40.1), "Hard drop and resolution keep the timer running")
		var level_one_speed := player.fall_interval()
		player.start(2)
		expect(player.play_time == 0.0 and player.fall_interval() > level_one_speed, "A new basket resets the time ramp")
		expect(player.fall_interval() < initial, "The new basket still starts faster than the previous one did")
		for phase in [Board.Phase.WON, Board.Phase.LOST]:
			player.board.phase = phase
			player.tick(100.0)
			expect(player.play_time == 0.0, "Completed baskets stop the speed timer")
		var previous := initial
		for seconds in range(0, 601, 20):
			var interval := Difficulty.fall_interval(preset, 1, seconds)
			expect(interval <= previous and interval >= 0.18, "Speed increases monotonically to a safe cap")
			previous = interval
		expect(is_equal_approx(previous, 0.18), "Long-running baskets reach the speed cap")
	# Check actual falling behavior, not just the computed interval.
	var fresh := Session.new()
	fresh.start()
	fresh.tick(0.73)
	expect(fresh.board.active.anchor.y == 0, "A new Normal basket does not fall within 730 ms")
	var faster := Session.new()
	faster.start()
	faster.tick(20.0)
	faster.fall_clock = 0.0
	var y: int = faster.board.active.anchor.y
	faster.tick(0.73)
	expect(faster.board.active.anchor.y == y + 1, "After 20 seconds Normal actually falls within 730 ms")
	var soft := Session.new()
	soft.start()
	soft.tick(20.0)
	soft.fall_clock = 0.0
	y = soft.board.active.anchor.y
	soft.tick(0.05, true)
	expect(soft.board.active.anchor.y == y, "Accelerated soft drop still waits for 55 ms")
	soft.tick(0.006, true)
	expect(soft.board.active.anchor.y == y + 1, "Soft drop retains its own fixed interval")
	# A shared clock keeps two boards equal through different resolution paths.
	var race := MatchState.new()
	race.reset(1729)
	race.tick(100.0)
	expect(race.play_time == 0.0, "Lobby does not advance pace")
	race.set_paused(false)
	race.tick(2.0)
	race.tick(1.0)
	expect(race.play_time == 0.0 and race.players[0].play_time == 0.0 and race.players[1].play_time == 0.0, "Opening countdown does not advance pace")
	race.tick(19.0)
	race.action(0, "drop")
	race.tick(1.0)
	expect(race.play_time == 20.0 and race.players[0].play_time == 20.0 and race.players[1].play_time == 20.0, "Both clocks stay identical when only one player is resolving a drop")
	expect(is_equal_approx(race.players[0].fall_interval(), 0.7225) and is_equal_approx(race.players[1].fall_interval(), 0.7225), "Both players accelerate together at the boundary")
	race.set_paused(true)
	race.tick(100.0)
	expect(race.play_time == 20.0 and race.players[0].play_time == 20.0, "Match pause freezes shared and player clocks")
	race.set_paused(false)
	race.tick(20.0, [false, true])
	expect(race.play_time == 40.0 and race.players[0].play_time == race.players[1].play_time, "Different drop speeds do not alter the shared timer")
	race.players[0].board.phase = Board.Phase.WON
	race.tick(0.0)
	race.tick(100.0)
	expect(race.play_time == 40.0, "Results screen stops acceleration")
	race.next_round()
	expect(race.play_time == 0.0 and race.players[0].play_time == 0.0 and race.players[1].play_time == 0.0, "Rematch resets all speed timers")
	var art := Art.new()
	fresh.start()
	expect(art.pace_label(fresh) == "SPEED 1.00× · UP IN 20s", "HUD explains initial pace and next increase")
	fresh.tick(20)
	expect(art.pace_label(fresh) == "SPEED 1.18× · UP IN 20s", "HUD shows the observed rate increase")
	fresh.play_time = 600
	expect(art.pace_label(fresh).ends_with(" · MAX"), "HUD reports the cap instead of another countdown")
	for preset in range(3):
		fresh.difficulty = preset
		for seconds in [0.0, 19.0, 20.0, 39.0, 180.0, 600.0]:
			fresh.play_time = seconds
			var width := art.font.get_string_size(art.pace_label(fresh), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			expect(width <= 208.0, "Pace indicator fits the narrower versus column")
	art.free()
	print("Speed progression: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
