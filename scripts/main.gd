extends "res://scripts/puzzle_art.gd"

const Session = preload("res://scripts/session.gd")
const Board = preload("res://scripts/board.gd")
const Controls = preload("res://scripts/controls.gd")
const BOARD_ORIGIN := Vector2(377, 130)
const BoardView = preload("res://scripts/board_view.gd")
const VersusScreen = preload("res://scripts/versus_screen.gd")
const Difficulty = preload("res://scripts/difficulty.gd")

var session := Session.new()
var board_view := BoardView.new()
var versus: Control
var solo_controls: Array = []
var ui := Control.new()
var menu := PanelContainer.new()
var shade := ColorRect.new()
var menu_kind := "title"
var muted := false
var reduced_motion := false
var high_score := 0
var difficulty := Difficulty.NORMAL
var sound := AudioStreamPlayer.new()
var repeat_clock := 0.0
var repeat_direction := 0
var repeat_started := false
var soft_touch := false
var controller := false
var mute_button: Button
var motion_button: Button
var pattern_button: Button
var ui_scale := 1.0
var ui_offset := Vector2.ZERO


func _ready() -> void:
	Controls.setup()
	title_font.font_names = PackedStringArray(["DejaVu Serif", "Georgia"])
	for kind in ["cat", "yarn"]:
		for color in ["orange", "blue", "purple"]:
			var key: String = kind + "_" + color
			var path: String = "res://assets/renders/" + key + ".png"
			if not ResourceLoader.exists(path):
				path = "res://assets/sprites/" + key + ".png"
			textures[key] = load(path)
	load_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			session.run_seed = int(arg.trim_prefix("--seed="))
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	add_child(sound)
	board_view.session = session
	board_view.textures = textures
	board_view.position = BOARD_ORIGIN
	board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(board_view)
	make_button("Pause  ·  Esc / Start", Vector2(766, 543), Vector2(278, 46), toggle_pause)
	mute_button = make_button("", Vector2(766, 600), Vector2(278, 42), toggle_mute)
	motion_button = make_button("", Vector2(766, 651), Vector2(278, 42), toggle_motion)
	pattern_button = make_button("", Vector2(766, 702), Vector2(278, 42), toggle_patterns)
	update_settings_labels()
	var touch_names := ["←", "↺", "↓", "↻", "→", "Drop"]
	var touch_actions := ["left", "reverse", "soft", "rotate", "right", "drop"]
	for i in range(touch_names.size()):
		var action: String = touch_actions[i]
		var button := make_button(touch_names[i], Vector2(358 + i * 61, 807), Vector2(55, 44), func(): touch_action(action))
		button.focus_mode = Control.FOCUS_NONE
		if action == "soft":
			button.button_down.connect(func(): soft_touch = true)
			button.button_up.connect(func(): soft_touch = false)
	solo_controls = ui.get_children()
	versus = VersusScreen.new()
	versus.host = self
	versus.textures = textures
	versus.hide()
	ui.add_child(versus)
	shade.color = Color(0.08, 0.16, 0.13, 0.65)
	shade.size = Vector2(1100, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(shade)
	ui.add_child(menu)
	menu.position = Vector2(293, 215)
	menu.size = Vector2(514, 450)
	menu.add_theme_stylebox_override("panel", panel_style(CREAM, 24, Color("b6c5ab"), 2))
	Input.joy_connection_changed.connect(controller_changed)
	controller = not Input.get_connected_joypads().is_empty()
	get_window().focus_exited.connect(func():
		if versus.visible:
			versus.pause_for_focus()
		elif menu_kind.is_empty():
			toggle_pause()
	)
	session.difficulty = difficulty
	session.start()
	show_menu("title")
	resized.connect(update_layout)
	update_layout()
	# Deterministic showcase mode used by screenshot validation.
	if OS.get_cmdline_user_args().has("--showcase"):
		start_game()
		session.board.active.anchor = Vector2i(3, 5)
		session.paused = true
	if OS.get_cmdline_user_args().has("--versus-showcase"):
		start_versus()
		versus.inputs.keyboard(0)
		versus.inputs.keyboard(1)
		versus.begin_round()
		versus.match_state.countdown = 0.0
		for i in range(2):
			versus.match_state.players[i].board.active.anchor = Vector2i(2 + i, 4 + i)
		versus.match_state.set_paused(true)
	if OS.get_cmdline_user_args().has("--versus-lobby"):
		start_versus()
	if OS.get_cmdline_user_args().has("--versus-pause"):
		versus.show_menu("pause")
	if OS.get_cmdline_user_args().has("--screenshot"):
		capture.call_deferred()


func capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var filename := "versus-lobby" if OS.get_cmdline_user_args().has("--versus-lobby") else ("versus" if versus.visible else "gameplay")
	if OS.get_cmdline_user_args().has("--versus-pause"):
		filename = "versus-pause"
	elif OS.get_cmdline_user_args().has("--title-showcase"):
		filename = "title"
	var result := shot.save_png("res://artifacts/%s.png" % filename)
	if result != OK:
		push_error("Could not save screenshot")
	get_tree().quit()


func update_layout() -> void:
	ui_scale = minf(size.x / 1100.0, size.y / 900.0)
	ui_offset = (size - Vector2(1100, 900) * ui_scale) * 0.5
	ui.position = ui_offset
	ui.scale = Vector2.ONE * ui_scale
	queue_redraw()


func make_button(text: String, pos: Vector2, dimensions: Vector2, callback: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.custom_minimum_size = dimensions
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", button_style(INK))
	button.add_theme_stylebox_override("hover", button_style(Color("405f4c")))
	button.add_theme_stylebox_override("pressed", button_style(Color("172f28")))
	button.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, 10, Color("e7b563"), 3))
	button.pressed.connect(callback)
	if parent == null:
		button.focus_mode = Control.FOCUS_NONE
	(ui if parent == null else parent).add_child(button)
	return button


func button_style(color: Color) -> StyleBoxFlat:
	var style := panel_style(color, 10)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func make_label(text: String, font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func show_menu(kind: String) -> void:
	menu_kind = kind
	session.paused = true
	soft_touch = false
	repeat_direction = 0
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	menu.show()
	shade.show()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	menu.add_child(column)
	var heading := "A little tangle. A lot of purr."
	var copy := "Pair up the cats. Match 4 of one color\nin a straight line to rescue the kittens.\nClear every yarn ball to finish the basket."
	var cta := "Let’s untangle"
	if kind == "pause":
		heading = "Taking a catnap"
		copy = "Your basket can wait.\nPieces and chain reactions are paused."
		cta = "Keep playing"
	elif kind == "won":
		heading = "Every kitten, rescued!"
		copy = "Basket %d is clear.\nScore  %s\nReady for a little more mischief?" % [session.board.level, format_score(session.board.score)]
		cta = "Next basket"
	elif kind == "lost":
		heading = "A very full basket"
		copy = "No room for the next pair.\nYou reached basket %d with %s points." % [session.board.level, format_score(session.board.score)]
		cta = "Try again"
	make_label("PURR & TANGLE", 15, column)
	make_label(heading, 27, column)
	make_label(copy, 18, column)
	make_button(cta, Vector2.ZERO, Vector2(450, 49), menu_primary, column)
	if kind == "title":
		make_button("Local two-player versus", Vector2.ZERO, Vector2(450, 46), start_versus, column)
		var difficulty_button := make_button(difficulty_label(), Vector2.ZERO, Vector2(450, 42), cycle_difficulty, column)
		var difficulty_copy := make_label(Difficulty.DESCRIPTIONS[difficulty], 15, column)
		difficulty_button.pressed.connect(func():
			difficulty_button.text = difficulty_label()
			difficulty_copy.text = Difficulty.DESCRIPTIONS[difficulty]
		)
	if kind == "pause":
		make_button("Restart this run", Vector2.ZERO, Vector2(450, 44), start_game, column)
		var sound_option := make_button(mute_button.text, Vector2.ZERO, Vector2(450, 40), toggle_mute, column)
		sound_option.pressed.connect(func(): sound_option.text = mute_button.text)
		var motion_option := make_button(motion_button.text, Vector2.ZERO, Vector2(450, 40), toggle_motion, column)
		motion_option.pressed.connect(func(): motion_option.text = motion_button.text)
		var patterns_option := make_button(pattern_button.text, Vector2.ZERO, Vector2(450, 40), toggle_patterns, column)
		patterns_option.pressed.connect(func(): patterns_option.text = pattern_button.text)
	if kind != "title":
		make_button("Main menu", Vector2.ZERO, Vector2(450, 40), return_to_title, column)
	make_label("← →  Move    ↑ / X  Rotate    Z  Reverse\n↓  Soft drop    Space  Drop    Esc  Pause", 15, column)
	make_label("Controller: stick / D-pad · A / B rotate\nX drops · Start pauses · A selects menus", 14, column)
	# Keep controller focus inside the modal, including wraparound.
	var options: Array = []
	for child in column.get_children():
		if child is Button:
			options.append(child)
	for i in range(options.size()):
		var button: Button = options[i]
		button.focus_neighbor_top = button.get_path_to(options[(i - 1 + options.size()) % options.size()])
		button.focus_neighbor_bottom = button.get_path_to(options[(i + 1) % options.size()])
		button.focus_next = button.focus_neighbor_bottom
		button.focus_previous = button.focus_neighbor_top
	menu.position.y = 65 if kind == "pause" else 160
	menu.size = Vector2(514, 450)
	focus_primary.call_deferred()
	queue_redraw()


func menu_primary() -> void:
	match menu_kind:
		"title", "lost": start_game()
		"pause": resume_game()
		"won":
			session.start(session.board.level + 1, session.board.score)
			board_view.reset()
			resume_game()


func start_game() -> void:
	session.difficulty = difficulty
	session.start()
	board_view.reset()
	resume_game()


func resume_game() -> void:
	menu_kind = ""
	menu.hide()
	shade.hide()
	session.paused = false
	repeat_direction = 0
	repeat_clock = 0.0
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func toggle_pause() -> void:
	if versus.visible:
		versus.toggle_pause()
		return
	if menu_kind == "pause":
		resume_game()
	elif menu_kind.is_empty():
		show_menu("pause")


func touch_action(action: String) -> void:
	if menu_kind.is_empty() and action != "soft":
		session.action(action)


func controller_changed(device: int, connected: bool) -> void:
	controller = not Input.get_connected_joypads().is_empty()
	if versus.visible:
		versus.controller_changed(device, connected)
		return
	if not connected and menu_kind.is_empty():
		show_menu("pause")


func _input(event: InputEvent) -> void:
	if versus.visible:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventKey:
		controller = false
	if event.is_action_pressed("pause_game") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif menu_kind == "pause" and event.is_action_pressed("ui_cancel") and not event.is_echo():
		resume_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("mute") and not event.is_echo():
		toggle_mute()


func _process(delta: float) -> void:
	if versus.visible:
		return
	board_view.reduced_motion = reduced_motion
	board_view.show_patterns = show_patterns
	board_view.queue_redraw()
	if not menu_kind.is_empty():
		queue_redraw()
		return
	delta = minf(delta, 0.1)
	var before: int = session.board.phase
	var direction := int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	if direction != repeat_direction:
		repeat_direction = direction
		repeat_clock = 0.0
		repeat_started = false
		if direction != 0:
			session.action("left" if direction < 0 else "right")
	elif direction != 0:
		repeat_clock += delta
		if repeat_clock >= (0.075 if repeat_started else 0.2):
			session.action("left" if direction < 0 else "right")
			repeat_clock = 0.0
			repeat_started = true
	for action in ["rotate", "reverse", "drop"]:
		if Input.is_action_just_pressed(action):
			session.action(action)
	session.tick(delta, Input.is_action_pressed("soft") or soft_touch)
	var after: int = session.board.phase
	if before == Board.Phase.PLAYING and after != Board.Phase.PLAYING:
		play_tone(220.0, 0.045)
	if before == Board.Phase.CLEARING and after == Board.Phase.GRAVITY:
		play_tone(520.0 + session.board.chain * 100.0, 0.12)
	board_view.animate(delta, before)
	if after in [Board.Phase.WON, Board.Phase.LOST]:
		high_score = maxi(high_score, session.board.score)
		save_settings()
		show_menu("won" if after == Board.Phase.WON else "lost")
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e4e6d7"))
	if versus.visible:
		return
	draw_set_transform(ui_offset, 0.0, Vector2.ONE * ui_scale)
	draw_rect(Rect2(0, 0, 1100, 900), CREAM)
	# Calm room background, with a broad sun patch and a low shelf.
	draw_circle(Vector2(125, 180), 250, Color("e8e9d7"))
	draw_circle(Vector2(1010, 870), 200, Color("dde4d3"))
	draw_line(Vector2(0, 785), Vector2(1100, 785), Color("d4d7c3"), 2)
	text_at("THE COZY PUZZLE CLUB", Vector2(48, 56), 13, MUTED)
	text_at("Purr &", Vector2(46, 139), 48, INK, title_font)
	text_at("Tangle", Vector2(46, 193), 48, INK, title_font)
	text_at("A basket full of little rescues.", Vector2(49, 228), 16, MUTED)
	draw_texture_rect(textures.get("cat_orange"), Rect2(62, 262, 225, 225), false)
	card(Rect2(48, 500, 270, 234), Color("e5e9d9"))
	text_at("MAKE ROOM FOR JOY", Vector2(70, 532), 13, MUTED)
	text_at("Match four.", Vector2(70, 571), 27, INK, title_font)
	text_at("Rescue every kitten.", Vector2(70, 605), 22, INK, title_font)
	text_at("Cats fall. Yarn stays put.", Vector2(70, 642), 16, MUTED)
	text_at("Keep pairs together, or split", Vector2(70, 672), 15, MUTED)
	text_at("them to start a chain reaction.", Vector2(70, 695), 15, MUTED)
	text_at("BEST  " + format_score(high_score), Vector2(50, 766), 15, MUTED)
	text_at("BASKET %02d · %s" % [session.board.level, Difficulty.NAMES[session.difficulty].to_upper()], Vector2(377, 66), 17, INK)
	text_at(pace_label(session), Vector2(377, 91), 13, MUTED)
	card(Rect2(754, 116, 302, 127), Color("e4e9d8"))
	text_at("YOUR SCORE", Vector2(778, 150), 13, MUTED)
	text_at(format_score(session.board.score), Vector2(775, 208), 45, INK, title_font)
	card(Rect2(754, 259, 302, 96), Color("ece2ce"))
	text_at("KITTENS TO RESCUE", Vector2(778, 291), 13, MUTED)
	text_at("%02d" % session.board.remaining_yarn(), Vector2(778, 332), 31, INK)
	text_at("hidden in yarn tangles", Vector2(835, 328), 14, MUTED)
	card(Rect2(754, 376, 302, 143), Color("d7b98b"))
	draw_line(Vector2(754, 414), Vector2(1056, 414), Color("b3956d"), 2)
	text_at("NEXT LITTLE HELPERS", Vector2(778, 405), 13, INK)
	for i in range(session.board.next_pair.size()):
		draw_piece(Vector2(830 + i * 82, 468), session.board.next_pair[i], false, 78.0)
	if session.board.chain > 1:
		text_at("%d×  CHAIN!" % session.board.chain, Vector2(785, 780), 26, INK)
	text_at("← →  /  STICK   MOVE", Vector2(374, 879), 12, MUTED)
	text_at("A / B   ROTATE     X   DROP" if controller else "↑ / Z   ROTATE     SPACE   DROP", Vector2(760, 849), 13, MUTED)
	text_at("A calm mind. A clever pair.", Vector2(48, 852), 16, MUTED, title_font)


func toggle_mute() -> void:
	muted = not muted
	sound.stop()
	update_settings_labels()
	save_settings()


func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	update_settings_labels()
	save_settings()


func toggle_patterns() -> void:
	show_patterns = not show_patterns
	update_settings_labels()
	save_settings()


func update_settings_labels() -> void:
	mute_button.text = "Sound: off" if muted else "Sound: on"
	motion_button.text = "Motion: reduced" if reduced_motion else "Motion: gentle"
	pattern_button.text = "Pattern cues: on" if show_patterns else "Pattern cues: off"


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		muted = config.get_value("accessibility", "muted", false)
		reduced_motion = config.get_value("accessibility", "reduced_motion", false)
		show_patterns = config.get_value("accessibility", "patterns", true)
		high_score = config.get_value("game", "best", 0)
		difficulty = Difficulty.valid(int(config.get_value("game", "difficulty", Difficulty.NORMAL)))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "muted", muted)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "patterns", show_patterns)
	config.set_value("game", "best", high_score)
	config.set_value("game", "difficulty", difficulty)
	if config.save("user://settings.cfg") != OK:
		push_warning("Settings could not be saved")


func play_tone(frequency: float, duration: float) -> void:
	if muted:
		return
	var samples := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / 22050.0
		var envelope := sin(PI * float(i) / samples) * exp(-t * 16)
		var value := sin(TAU * frequency * t) * envelope * 0.13
		data.encode_s16(i * 2, int(value * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	sound.stream = stream
	sound.play()


func start_versus() -> void:
	session.paused = true
	menu_kind = "versus"
	menu.hide()
	shade.hide()
	for control in solo_controls:
		control.hide()
	versus.show()
	versus.open_lobby(session.run_seed)
	queue_redraw()


func return_to_title() -> void:
	versus.hide()
	versus.match_state.set_paused(true)
	for control in solo_controls:
		control.show()
	show_menu("title")


func difficulty_label() -> String:
	return "Difficulty: %s · select to change" % Difficulty.NAMES[difficulty]


func cycle_difficulty() -> void:
	difficulty = (difficulty + 1) % Difficulty.NAMES.size()
	save_settings()
	if menu_kind == "title":
		session.difficulty = difficulty
		session.start()
		board_view.reset()


func focus_primary() -> void:
	# Rebuilding a menu twice in one frame must not focus a removed button.
	if menu.visible and menu.get_child_count() > 0:
		for child in menu.get_child(0).get_children():
			if child is Button and not child.disabled:
				child.grab_focus()
				return
