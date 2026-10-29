class_name InputBindings
## The player's key and controller bindings: which actions can be rebound,
## how a binding is saved, named and swapped when it clashes with another.
##
## Each rebindable action has a keyboard slot and a controller slot on the
## Controls tab, and one option in OptionsSettings (option_key()) whose value
## is the action's events, serialized. The live bindings are the InputMap
## itself: an option's write puts the events there, its read takes them back
## out, and its default is what project.godot gives the action, so "Defaults"
## restores the project's bindings.

enum Kind {KEY, PAD}

## The actions the player can rebind, in the order the Controls tab lists
## them. The dev console's key isn't one.
const ACTIONS: Array[StringName] = [
	&"EndTurn", &"PauseMenu", &"target_left", &"target_right", &"screenshot",
	&"cursor_click", &"cursor_back",
]

## The controller's stand-ins for the mouse buttons (see VirtualCursor). The
## keyboard has a mouse already.
const PAD_ONLY: Array[StringName] = [&"cursor_click", &"cursor_back"]

## Each action's name on the Controls tab, a translation key.
const LABEL_KEYS: Dictionary[StringName, String] = {
	&"EndTurn": "OPT_ACTION_END_TURN",
	&"PauseMenu": "OPT_ACTION_PAUSE",
	&"target_left": "OPT_ACTION_TARGET_LEFT",
	&"target_right": "OPT_ACTION_TARGET_RIGHT",
	&"screenshot": "OPT_ACTION_SCREENSHOT",
	&"cursor_click": "OPT_ACTION_CLICK",
	&"cursor_back": "OPT_ACTION_BACK",
}

## Bindings no rebindable action may take: they'd fire both.
const RESERVED_ACTIONS: Array[StringName] = [&"DevConsole"]

## Shown on a slot with nothing bound.
const UNBOUND_LABEL: String = "-"

## Controller buttons by their Xbox names, which Steam Deck shares. Ones that
## are words are translation keys.
const _PAD_BUTTON_NAMES: Dictionary[JoyButton, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "OPT_PAD_SELECT",
	JOY_BUTTON_START: "OPT_PAD_START",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_PADDLE1: "P1",
	JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3",
	JOY_BUTTON_PADDLE4: "P4",
}

## Long engine key names cut down to fit a slot; words are translation keys.
const _KEY_NAMES: Dictionary[Key, String] = {
	KEY_SPACE: "OPT_KEY_SPACE",
	KEY_ENTER: "OPT_KEY_ENTER",
	KEY_KP_ENTER: "OPT_KEY_ENTER",
	KEY_ESCAPE: "OPT_KEY_ESCAPE",
	KEY_BACKSPACE: "OPT_KEY_BACKSPACE",
	KEY_TAB: "OPT_KEY_TAB",
	KEY_DELETE: "Del",
	KEY_INSERT: "Ins",
	KEY_PAGEUP: "PgUp",
	KEY_PAGEDOWN: "PgDn",
	KEY_LEFT: "OPT_KEY_LEFT",
	KEY_RIGHT: "OPT_KEY_RIGHT",
	KEY_UP: "OPT_KEY_UP",
	KEY_DOWN: "OPT_KEY_DOWN",
}

## Triggers are axes; this far in counts as a press.
const TRIGGER_PRESS: float = 0.6


## --- Options ---

static func option_key(action: StringName) -> StringName:
	return StringName("Controls/bind_" + action)


## What project.godot binds [param action] to, serialized.
static func default_value(action: StringName) -> Array:
	var setting: Variant = ProjectSettings.get_setting("input/" + action)
	if not setting is Dictionary:
		return []
	var events: Array[InputEvent] = []
	for event: Variant in setting.get("events", []):
		if event is InputEvent:
			events.append(event)
	return serialize(events)


## [param action]'s live bindings, serialized.
static func read(action: StringName) -> Array:
	return serialize(InputMap.action_get_events(action))


## Makes [param value] (as read() gives it) [param action]'s bindings. A value
## that isn't a list, from a damaged file, restores the default instead.
static func write(action: StringName, value: Variant) -> void:
	var serialized: Array = value if value is Array else default_value(action)
	InputMap.action_erase_events(action)
	for event: InputEvent in deserialize(serialized):
		InputMap.action_add_event(action, event)


## --- Serializing ---

## Events as short strings for the options file: "key:32", "pad:3",
## "axis:5:1". Kinds a binding can't hold are dropped.
static func serialize(events: Array[InputEvent]) -> Array:
	var result: Array = []
	for event: InputEvent in events:
		var text: String = _serialize_event(event)
		if text != "" and not result.has(text):
			result.append(text)
	return result


## The events serialize() wrote. Entries it can't read are skipped.
static func deserialize(serialized: Array) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for entry: Variant in serialized:
		var event: InputEvent = _deserialize_event(str(entry))
		if event:
			result.append(event)
	return result


static func _serialize_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: Key = _key_code(event)
		return "key:%d" % key if key != KEY_NONE else ""
	if event is InputEventJoypadButton:
		return "pad:%d" % event.button_index
	if event is InputEventJoypadMotion:
		return "axis:%d:%d" % [event.axis, 1 if event.axis_value >= 0.0 else -1]
	return ""


static func _deserialize_event(text: String) -> InputEvent:
	var parts: PackedStringArray = text.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	match parts[0]:
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(parts[1]) as Key
			return key
		"pad":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.device = -1
			button.button_index = int(parts[1]) as JoyButton
			return button
		"axis":
			if parts.size() < 3 or not parts[2].is_valid_int():
				return null
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.device = -1
			motion.axis = int(parts[1]) as JoyAxis
			motion.axis_value = signf(float(parts[2]))
			return motion
	return null


## --- Rebinding ---

## Whether [param event] can go in a [param kind] slot, as a press: keys for
## the keyboard, buttons and triggers for the controller. The left stick and
## d-pad steer the cursor, and the guide button belongs to Steam.
static func accepts(kind: Kind, event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _is_reserved(event):
		return false
	match kind:
		Kind.KEY:
			return event is InputEventKey and _key_code(event) != KEY_NONE
		Kind.PAD:
			if event is InputEventJoypadButton:
				return not event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
					JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_GUIDE]
			if event is InputEventJoypadMotion:
				return event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] \
					and event.axis_value >= TRIGGER_PRESS
	return false


## The new bindings, serialized, of every action that changes when
## [param event] becomes [param action]'s only [param kind] binding. Another
## action already using that event gives it up and takes over the bindings
## [param action] had, so the two swap rather than one being left without.
static func plan_bind(action: StringName, kind: Kind, event: InputEvent) -> Dictionary[StringName, Array]:
	var changes: Dictionary[StringName, Array] = {}
	var bound: InputEvent = _deserialize_event(_serialize_event(event))
	if not bound:
		return changes
	var old: Array[InputEvent] = events_of_kind(action, kind)
	if old.size() == 1 and _same(old[0], bound):
		return changes

	var kept: Array[InputEvent] = _other_kind(InputMap.action_get_events(action), kind)
	kept.append(bound)
	changes[action] = serialize(kept)

	var handed_over: Array[InputEvent] = old.filter(func(each: InputEvent) -> bool: return not _same(each, bound))
	for other: StringName in ACTIONS:
		if other == action or not _has_event(other, bound):
			continue
		var remaining: Array[InputEvent] = InputMap.action_get_events(other).filter(
			func(each: InputEvent) -> bool: return not _same(each, bound))
		remaining.append_array(handed_over)
		changes[other] = serialize(remaining)
		# Only the first clash takes the old bindings; defaults never share.
		handed_over = []
	return changes


## [param action]'s bindings of [param kind], in InputMap order.
static func events_of_kind(action: StringName, kind: Kind) -> Array[InputEvent]:
	return InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return _kind_of(event) == kind)


## The name to show for [param action]'s [param kind] slot: its first binding,
## or UNBOUND_LABEL.
static func slot_label(action: StringName, kind: Kind) -> String:
	var events: Array[InputEvent] = events_of_kind(action, kind)
	return event_label(events[0]) if not events.is_empty() else UNBOUND_LABEL


## A short, readable name for [param event]: "Space", "Q", "LB", "RT".
## Letters follow the player's keyboard layout where the platform says how.
static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var physical: Key = _key_code(event)
		if _KEY_NAMES.has(physical):
			return TranslationServer.translate(_KEY_NAMES[physical])
		var shown: Key = physical
		if DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(physical)
		if shown == KEY_NONE:
			shown = physical
		# Punctuation as itself ("\\", not "BackSlash"); letters are capitals.
		if shown > KEY_SPACE and shown < 127:
			return char(shown)
		return OS.get_keycode_string(shown)
	if event is InputEventJoypadButton:
		var name: String = _PAD_BUTTON_NAMES.get(event.button_index, "")
		return TranslationServer.translate(name) if name != "" else "#%d" % event.button_index
	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
		return "Axis %d" % event.axis
	return UNBOUND_LABEL


## --- Internals ---

static func _kind_of(event: InputEvent) -> int:
	if event is InputEventKey:
		return Kind.KEY
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Kind.PAD
	return -1


static func _other_kind(events: Array[InputEvent], kind: Kind) -> Array[InputEvent]:
	return events.filter(func(event: InputEvent) -> bool: return _kind_of(event) != kind)


## Keys are bound by position on the keyboard (physical_keycode), so WASD-style
## choices survive a layout change; an event with only a keycode falls back
## to it.
static func _key_code(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


static func _same(a: InputEvent, b: InputEvent) -> bool:
	var text: String = _serialize_event(a)
	return text != "" and text == _serialize_event(b)


static func _has_event(action: StringName, event: InputEvent) -> bool:
	return InputMap.action_get_events(action).any(func(each: InputEvent) -> bool: return _same(each, event))


static func _is_reserved(event: InputEvent) -> bool:
	for action: StringName in RESERVED_ACTIONS:
		if InputMap.has_action(action) and _has_event(action, event):
			return true
	return false
