extends "res://scripts/puzzle_art.gd"
## Local match presentation and device-aware lobby/menu handling.

const MatchState = preload("res://scripts/versus_match.gd")
const Inputs = preload("res://scripts/versus_input.gd")
const BoardView = preload("res://scripts/board_view.gd")
const Board = preload("res://scripts/board.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const ORIGINS := [Vector2(80, 150), Vector2(700, 150)]

var host: Control
var match_state := MatchState.new()
var inputs := Inputs.new()
var views: Array = []
var mode := "lobby"
var modal := PanelContainer.new()
var shade := ColorRect.new()
var join_presses: Dictionary = {}


func _ready() -> void:
	size = Vector2(1100, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_font.font_names = PackedStringArray(["DejaVu Serif", "Georgia"])
	for i in range(2):
		var view := BoardView.new()
		view.session = match_state.players[i]
		view.position = ORIGINS[i]
		view.textures = textures
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(view)
		views.append(view)
	var pause: Button = host.make_button("Pause · Start / Esc", Vector2(443, 702), Vector2(214, 44), toggle_pause, self)
	pause.focus_mode = Control.FOCUS_NONE
	shade.color = Color(0.08, 0.16, 0.13, 0.72)
	shade.size = size
	add_child(shade)
	modal.add_theme_stylebox_override("panel", panel_style(CREAM, 24, Color("b6c5ab"), 2))
	add_child(modal)


func open_lobby(seed_value: int) -> void:
	inputs = Inputs.new()
	join_presses.clear()
	match_state.reset(seed_value, host.difficulty)
	for view in views:
		view.reset()
	show_menu("lobby")


func show_menu(next_mode: String) -> void:
	mode = next_mode
	match_state.set_paused(true)
	inputs.clear()
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	modal.add_child(column)
	var heading := "Two baskets. One friendly race."
	var copy := "Each player: press A on a different controller,\nor choose a keyboard below."
	var cta := "Start the race"
	if mode == "pause":
		heading = "A catnap for two"
		copy = "Both baskets are paused."
		if not inputs.ready():
			copy += "\nController disconnected. Press A to rejoin,\nor use the missing player’s keyboard."
		cta = "Keep playing"
	elif mode == "result":
		heading = "A purr-fect tie!" if match_state.result == MatchState.Result.DRAW else "Player %d wins!" % match_state.result
		copy = "Round %d complete · Wins %d : %d\nNext round: more tangles, faster cats." % [match_state.round_number, match_state.wins[0], match_state.wins[1]]
		cta = "Play round %d" % (match_state.round_number + 1)
	host.make_label("PURR & TANGLE · LOCAL VERSUS", 14, column)
	host.make_label(heading, 25, column)
	if mode == "result":
		var portraits := HBoxContainer.new()
		portraits.add_theme_constant_override("separation", 18)
		column.add_child(portraits)
		for slot in range(2):
			var player := VBoxContainer.new()
			player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			portraits.add_child(player)
			var won := match_state.result == slot + 1
			var tied := match_state.result == MatchState.Result.DRAW
			# A simultaneous rescue and a simultaneous blocked basket are both ties.
			var rescued: bool = match_state.players[slot].board.phase == Board.Phase.WON
			add_outcome_art(player, "won" if won or (tied and rescued) else "lost", 170.0)
			host.make_label("P%d · %s" % [slot + 1, "Tie" if tied else ("Winner" if won else "Next time!")], 15, player)
	host.make_label(copy, 17, column)
	host.make_label("P1: %s\nP2: %s" % [inputs.label(0), inputs.label(1)], 16, column)
	var primary: Button = host.make_button(cta, Vector2.ZERO, Vector2(490, 46), begin_round, column)
	primary.disabled = not inputs.ready()
	for slot in range(2):
		if mode == "lobby" or inputs.devices[slot] == Inputs.EMPTY:
			var label := "P1 keyboard · WASD / Q / E (F1)" if slot == 0 else "P2 keyboard · arrows / , / . (F2)"
			host.make_button(label, Vector2.ZERO, Vector2(490, 40), func(): use_keyboard(slot), column)
	if mode == "lobby":
		host.make_button(host.difficulty_label(), Vector2.ZERO, Vector2(490, 40), cycle_difficulty, column)
		host.make_label(Difficulty.DESCRIPTIONS[match_state.difficulty], 15, column)
	if mode == "pause":
		for option in ["sound", "motion", "patterns"]:
			var label: String = host.mute_button.text if option == "sound" else (host.motion_button.text if option == "motion" else host.pattern_button.text)
			host.make_button(label, Vector2.ZERO, Vector2(490, 38), func(): change_setting(option), column)
	host.make_button("Main menu", Vector2.ZERO, Vector2(490, 40), host.return_to_title, column)
	host.make_label("Clear your yarn first, or outlast a full basket.\nSame layouts, same pairs, same speed for both players.", 14, column)
	var options: Array = []
	for child in column.get_children():
		if child is Button and not child.disabled:
			options.append(child)
	for i in range(options.size()):
		var button: Button = options[i]
		button.focus_neighbor_top = button.get_path_to(options[(i - 1 + options.size()) % options.size()])
		button.focus_neighbor_bottom = button.get_path_to(options[(i + 1) % options.size()])
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom
	modal.position = Vector2(287, 90 if mode == "result" else (105 if mode == "pause" else 180))
	modal.size = Vector2(526, 0)
	modal.show()
	shade.show()
	focus_option.call_deferred()
	queue_redraw()


func use_keyboard(slot: int) -> void:
	inputs.keyboard(slot)
	show_menu(mode)


func cycle_difficulty() -> void:
	host.cycle_difficulty()
	match_state.reset(match_state.run_seed, host.difficulty)
	for view in views:
		view.reset()
	show_menu("lobby")
	focus_option.call_deferred(host.difficulty_label())


func focus_option(preferred: String = "") -> void:
	if not modal.visible or modal.get_child_count() == 0:
		return
	for child in modal.get_child(0).get_children():
		if child is Button and not child.disabled and (preferred.is_empty() or child.text == preferred):
			child.grab_focus()
			return


func change_setting(option: String) -> void:
	match option:
		"sound": host.toggle_mute()
		"motion": host.toggle_motion()
		"patterns": host.toggle_patterns()
	show_menu(mode)


func begin_round() -> void:
	if not inputs.ready():
		return
	if mode == "result":
		match_state.next_round()
		for view in views:
			view.reset()
	mode = ""
	modal.hide()
	shade.hide()
	inputs.clear()
	match_state.set_paused(false)
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func toggle_pause() -> void:
	if mode == "pause":
		begin_round()
	elif mode.is_empty():
		show_menu("pause")


func pause_for_focus() -> void:
	if mode.is_empty():
		show_menu("pause")


func controller_changed(device: int, connected: bool) -> void:
	if not connected:
		join_presses.erase(device)
		if inputs.remove_device(device) >= 0:
			show_menu("pause" if mode.is_empty() else mode)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if joy:
		# Consume both halves of the joining press, so A cannot also start a race.
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and join_presses.has(event.device):
			if not event.pressed:
				join_presses.erase(event.device)
			get_viewport().set_input_as_handled()
			return
		if not inputs.devices.has(event.device):
			if not mode.is_empty() and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
				if inputs.join(event.device) >= 0:
					join_presses[event.device] = true
					show_menu(mode)
			get_viewport().set_input_as_handled()
			return
		if mode == "lobby" and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			inputs.remove_device(event.device)
			show_menu("lobby")
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and not mode.is_empty():
		if event.keycode in [KEY_F1, KEY_F2]:
			use_keyboard(0 if event.keycode == KEY_F1 else 1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause_game") and not event.is_echo():
		if mode == "lobby":
			begin_round()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if mode == "pause" and event.is_action_pressed("ui_cancel") and not event.is_echo():
		begin_round()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("mute") and not event.is_echo():
		host.toggle_mute()
	if mode.is_empty():
		inputs.handle(event)
		if joy or event is InputEventKey:
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	delta = minf(delta, 0.1)
	show_patterns = host.show_patterns
	if mode.is_empty():
		var before: Array = [match_state.players[0].board.phase, match_state.players[1].board.phase]
		var soft: Array = [false, false]
		for i in range(2):
			var state := inputs.poll(i, delta)
			for action in state.actions:
				match_state.action(i, action)
			soft[i] = state.soft
		var counting_down: bool = match_state.countdown > 0.0
		match_state.tick(delta, soft)
		if counting_down and match_state.countdown == 0.0:
			inputs.clear()
		for i in range(2):
			views[i].animate(delta, before[i])
			var after: int = match_state.players[i].board.phase
			if before[i] == Board.Phase.CLEARING and after == Board.Phase.GRAVITY:
				host.play_tone(620.0 + i * 160.0, 0.12)
			elif before[i] == Board.Phase.PLAYING and after != Board.Phase.PLAYING:
				host.play_tone(220.0 + i * 50.0, 0.045)
		if match_state.result != MatchState.Result.PLAYING:
			show_menu("result")
	for view in views:
		view.reduced_motion = host.reduced_motion
		view.show_patterns = host.show_patterns
		view.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CREAM)
	draw_circle(Vector2(40, 80), 240, Color("e8e9d7"))
	draw_circle(Vector2(1050, 880), 220, Color("dde4d3"))
	text_at("PURR & TANGLE", Vector2(80, 45), 21, INK, title_font)
	text_at("LOCAL VERSUS · ROUND %02d" % match_state.round_number, Vector2(701, 45), 16, MUTED)
	for i in range(2):
		var x: float = ORIGINS[i].x
		var board: RefCounted = match_state.players[i].board
		text_at("PLAYER %d" % (i + 1), Vector2(x, 91), 19, INK)
		text_at("%d TO RESCUE" % board.remaining_yarn(), Vector2(x + 170, 91), 16, INK)
		text_at("SCORE  " + format_score(board.score), Vector2(x, 119), 14, MUTED)
		text_at("%d WIN%s" % [match_state.wins[i], "" if match_state.wins[i] == 1 else "S"], Vector2(x + 245, 119), 14, MUTED)
		var keyboard: bool = inputs.devices[i] < 0 and inputs.devices[i] != Inputs.EMPTY
		var hint := ("WASD  MOVE / ROTATE · Q REVERSE · E DROP" if i == 0 else "ARROWS MOVE / ROTATE · , REVERSE · . DROP") if keyboard else "STICK / D-PAD · A / B ROTATE · X DROP"
		text_at(hint, Vector2(x - 10, 851), 12, MUTED)
	text_at("A friendly", Vector2(466, 119), 23, INK, title_font)
	text_at("little rivalry.", Vector2(453, 151), 23, INK, title_font)
	for i in range(2):
		var y := 202 + i * 159
		card(Rect2(443, y, 214, 138), Color("d7b98b"))
		text_at("P%d · NEXT HELPERS" % (i + 1), Vector2(462, y + 29), 14, INK)
		var pair: Array = match_state.players[i].board.next_pair
		if pair.size() == 2:
			draw_yarn_link(Vector2(501, y + 88), Vector2(595, y + 88), 76.0)
		for j in range(pair.size()):
			draw_piece(Vector2(501 + j * 94, y + 88), pair[j], false, 76)
	text_at("FIRST TO CLEAR", Vector2(479, 546), 14, INK)
	text_at("ALL YARN WINS", Vector2(481, 570), 14, INK)
	text_at("%s · same pace" % Difficulty.NAMES[match_state.difficulty], Vector2(467, 606), 14, MUTED)
	text_at(pace_label(match_state.players[0]), Vector2(449, 637), 13, INK)
	if mode.is_empty() and match_state.countdown > 0.0:
		card(Rect2(447, 650, 206, 135), CREAM)
		text_at("GET READY", Vector2(487, 683), 16, INK)
		text_at(str(ceili(match_state.countdown)), Vector2(532, 750), 54, INK, title_font)
	text_at("More purrs. Twice the mischief.", Vector2(425, 889), 16, MUTED, title_font)
