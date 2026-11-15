extends RefCounted
## Route raw events by device. Shared InputMap actions intentionally do not
## drive versus play: Godot's default device=-1 would control both baskets.

const EMPTY := -99
const KEYBOARD_ONE := -1
const KEYBOARD_TWO := -2
const KEYS := [
	{KEY_A: "left", KEY_D: "right", KEY_S: "soft", KEY_W: "rotate", KEY_Q: "reverse", KEY_E: "drop"},
	{KEY_LEFT: "left", KEY_RIGHT: "right", KEY_DOWN: "soft", KEY_UP: "rotate", KEY_COMMA: "reverse", KEY_PERIOD: "drop"}
]
const BUTTONS := {
	JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right",
	JOY_BUTTON_DPAD_DOWN: "soft", JOY_BUTTON_A: "rotate",
	JOY_BUTTON_B: "reverse", JOY_BUTTON_X: "drop"
}

var devices: Array = [EMPTY, EMPTY]
var held: Array = [{}, {}]
var taps: Array = [[], []]
var axes: Array = [Vector2.ZERO, Vector2.ZERO]
var repeat_direction: Array = [0, 0]
var repeat_clock: Array = [0.0, 0.0]
var repeating: Array = [false, false]


func ready() -> bool:
	return not devices.has(EMPTY)


func join(device: int) -> int:
	if device < 0:
		return -1
	if devices.has(device):
		return devices.find(device)
	var slot := devices.find(EMPTY)
	if slot >= 0:
		devices[slot] = device
		clear()
	return slot


func keyboard(slot: int) -> void:
	assert(slot in [0, 1])
	devices[slot] = KEYBOARD_ONE if slot == 0 else KEYBOARD_TWO
	clear()


func remove_device(device: int) -> int:
	var slot := devices.find(device)
	if device >= 0 and slot >= 0:
		devices[slot] = EMPTY
		clear()
		return slot
	return -1


func clear() -> void:
	held = [{}, {}]
	taps = [[], []]
	axes = [Vector2.ZERO, Vector2.ZERO]
	repeat_direction = [0, 0]
	repeat_clock = [0.0, 0.0]
	repeating = [false, false]


func handle(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		for slot in range(2):
			if devices[slot] == (KEYBOARD_ONE if slot == 0 else KEYBOARD_TWO) and KEYS[slot].has(code):
				button(slot, "key:%d" % code, KEYS[slot][code], event.pressed)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var slot := devices.find(event.device)
		if slot < 0:
			return
		if event is InputEventJoypadButton and BUTTONS.has(event.button_index):
			button(slot, "button:%d" % event.button_index, BUTTONS[event.button_index], event.pressed)
		elif event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_LEFT_X:
				axes[slot].x = event.axis_value
			elif event.axis == JOY_AXIS_LEFT_Y:
				axes[slot].y = event.axis_value


func button(slot: int, source: String, action: String, pressed: bool) -> void:
	if pressed:
		if not held[slot].has(source) and action in ["rotate", "reverse", "drop"]:
			taps[slot].append(action)
		held[slot][source] = action
	else:
		held[slot].erase(source)


func is_down(slot: int, action: String) -> bool:
	return held[slot].values().has(action)


func poll(slot: int, delta: float) -> Dictionary:
	var right: bool = is_down(slot, "right") or axes[slot].x > 0.5
	var left: bool = is_down(slot, "left") or axes[slot].x < -0.5
	var direction := int(right) - int(left)
	var actions: Array = taps[slot].duplicate()
	taps[slot].clear()
	if direction != repeat_direction[slot]:
		repeat_direction[slot] = direction
		repeat_clock[slot] = 0.0
		repeating[slot] = false
		if direction != 0:
			actions.append("left" if direction < 0 else "right")
	elif direction != 0:
		repeat_clock[slot] += delta
		if repeat_clock[slot] >= (0.075 if repeating[slot] else 0.2):
			actions.append("left" if direction < 0 else "right")
			repeat_clock[slot] = 0.0
			repeating[slot] = true
	return {"actions": actions, "soft": is_down(slot, "soft") or axes[slot].y > 0.5}


func label(slot: int) -> String:
	if devices[slot] == EMPTY:
		return "Press A on a controller to join"
	if devices[slot] == KEYBOARD_ONE:
		return "Keyboard · WASD / Q / E"
	if devices[slot] == KEYBOARD_TWO:
		return "Keyboard · arrows / , / ."
	return "Controller %d · ready" % (devices[slot] + 1)
