class_name InputPrompts
extends RefCounted
## Resolves tutorial controls from the live bindings, using the last input's
## controller family. Unpictured buttons fall back to their binding name.

const _ROOT: String = "res://Assets/Textures/UI/InputPrompts/"
const _FAMILIES: Array[StringName] = [&"xbox", &"ps", &"steam"]
const _HEIGHT_EM: float = 1.5
const _BUTTON_NAMES: Dictionary[int, Array] = {
	JOY_BUTTON_A: ["a", "cross", "a"],
	JOY_BUTTON_B: ["b", "circle", "b"],
	JOY_BUTTON_X: ["x", "square", "x"],
	JOY_BUTTON_Y: ["y", "triangle", "y"],
	JOY_BUTTON_BACK: ["view", "share", "view"],
	JOY_BUTTON_START: ["menu", "options", "menu"],
	JOY_BUTTON_LEFT_STICK: ["ls", "l3", "l3"],
	JOY_BUTTON_RIGHT_STICK: ["rs", "r3", "r3"],
	JOY_BUTTON_LEFT_SHOULDER: ["lb", "l1", "l1"],
	JOY_BUTTON_RIGHT_SHOULDER: ["rb", "r1", "r1"],
	JOY_BUTTON_DPAD_UP: ["dpad_up", "dpad_up", "dpad_up"],
	JOY_BUTTON_DPAD_DOWN: ["dpad_down", "dpad_down", "dpad_down"],
	JOY_BUTTON_DPAD_LEFT: ["dpad_left", "dpad_left", "dpad_left"],
	JOY_BUTTON_DPAD_RIGHT: ["dpad_right", "dpad_right", "dpad_right"],
}


static func render_token(token: String, fallback: String) -> String:
	if not InputManager.controller_active:
		return fallback
	match token:
		"(left_mouse)":
			return _render_action(&"cursor_click")
		"(right_mouse)":
			return _render_action(&"cursor_back")
		"(arrow_keys)", "(targeting_arrows)":
			return _render_targets()
	return fallback


static func action_icon(action: StringName) -> Texture2D:
	var path: String = action_icon_path(action)
	return load(path) as Texture2D if not path.is_empty() else null


static func action_icon_path(action: StringName) -> String:
	var events: Array[InputEvent] = InputBindings.events_of_kind(action, InputBindings.Kind.PAD)
	return event_icon_path(events[0], InputManager.controller_family) if not events.is_empty() else ""


static func event_icon_path(event: InputEvent, family: StringName) -> String:
	var index: int = maxi(0, _FAMILIES.find(family))
	var names: Array = []
	if event is InputEventJoypadButton:
		names = _BUTTON_NAMES.get(event.button_index, [])
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			names = ["lt", "l2", "l2"]
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
			names = ["rt", "r2", "r2"]
	if names.is_empty():
		return ""
	var path: String = _ROOT + "%s_%s.png" % [_FAMILIES[index], names[index]]
	return path if ResourceLoader.exists(path) else ""


static func _render_action(action: StringName) -> String:
	var path: String = action_icon_path(action)
	if path.is_empty():
		return InputBindings.slot_label(action, InputBindings.Kind.PAD)
	return _image(path)


static func _render_targets() -> String:
	var left: Array[InputEvent] = InputBindings.events_of_kind(&"target_left", InputBindings.Kind.PAD)
	var right: Array[InputEvent] = InputBindings.events_of_kind(&"target_right", InputBindings.Kind.PAD)
	if not left.is_empty() and not right.is_empty() \
		and left[0] is InputEventJoypadButton and right[0] is InputEventJoypadButton:
		var l: int = (left[0] as InputEventJoypadButton).button_index
		var r: int = (right[0] as InputEventJoypadButton).button_index
		var suffix: String = ""
		if l == JOY_BUTTON_LEFT_SHOULDER and r == JOY_BUTTON_RIGHT_SHOULDER:
			suffix = "l1_r1" if InputManager.controller_family == &"ps" else "lb_rb"
		elif l == JOY_BUTTON_DPAD_LEFT and r == JOY_BUTTON_DPAD_RIGHT:
			suffix = "dpad"
		if not suffix.is_empty():
			return _image(_ROOT + "%s_%s.png" % [InputManager.controller_family, suffix])
	return _render_action(&"target_left") + "\u00a0" + _render_action(&"target_right")


static func _image(path: String) -> String:
	return "[img height=%sem]%s[/img]" % [_HEIGHT_EM, path]
