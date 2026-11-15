extends RefCounted
## Explicit gamepad actions; Godot's ui_* actions handle menu focus/activation.

static func setup() -> void:
	bind("left", [KEY_LEFT, KEY_A], JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	bind("right", [KEY_RIGHT, KEY_D], JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	bind("soft", [KEY_DOWN, KEY_S], JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	bind("rotate", [KEY_UP, KEY_W, KEY_X], JOY_BUTTON_A)
	bind("reverse", [KEY_Z], JOY_BUTTON_B)
	bind("drop", [KEY_SPACE], JOY_BUTTON_X)
	bind("pause_game", [KEY_ESCAPE, KEY_P], JOY_BUTTON_START)
	bind("mute", [KEY_M], JOY_BUTTON_INVALID)
	# Godot's default ui_accept is keyboard-only on this engine version.
	for mapping in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = mapping[1]
		if not InputMap.action_has_event(mapping[0], event):
			InputMap.action_add_event(mapping[0], event)


static func bind(action: String, keys: Array, button: int, axis: int = -1, value: float = 0.0) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.5)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if button != JOY_BUTTON_INVALID:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = button
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axis
		event.axis_value = value
		InputMap.action_add_event(action, event)
