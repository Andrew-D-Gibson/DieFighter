class_name BindingSlots
extends HBoxContainer
## The binding buttons on a Controls row: by default the action's key and its
## controller button, or just one of them (the Controls tab shows keyboard
## and controller bindings on separate pages). Clicking a slot listens for
## the next press (InputManager) and binds it through OptionsSettings, so
## it's saved, reset by "Defaults", and any action it was taken from shows
## its swapped binding when the page refreshes.

const SLOT_SIZE: Vector2 = Vector2(30, 14)
const _GAP: int = 2
const _LISTENING_TEXT: String = "..."

var action: StringName
var _slots: Dictionary[InputBindings.Kind, Button] = {}


## [param make_button] styles a button for the page (OptionsPage.styled_button).
func _init(bound_action: StringName, make_button: Callable,
		kinds: Array[InputBindings.Kind] = [InputBindings.Kind.KEY, InputBindings.Kind.PAD]) -> void:
	action = bound_action
	add_theme_constant_override("separation", _GAP)
	custom_minimum_size.x = SLOT_SIZE.x * kinds.size() + _GAP * (kinds.size() - 1)
	for kind: InputBindings.Kind in kinds:
		var slot: Button = make_button.call("")
		# A little shorter than a row, so stacked rows' slots don't touch.
		slot.custom_minimum_size = SLOT_SIZE
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBox = slot.get_theme_stylebox(state)
			style.content_margin_top = 0.0
			style.content_margin_bottom = 0.0
		slot.clip_text = true
		# Key names are translated (or not words) already.
		slot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		slot.pressed.connect(_on_slot_pressed.bind(kind))
		add_child(slot)
		_slots[kind] = slot


func _ready() -> void:
	InputManager.binding_captured.connect(_on_binding_captured)
	InputManager.binding_cancelled.connect(_on_binding_cancelled)
	visibility_changed.connect(_stop_if_hidden)
	refresh()


func _exit_tree() -> void:
	_stop_listening_here()


func slot(kind: InputBindings.Kind) -> Button:
	return _slots[kind]


## Re-reads the slots' bindings from the InputMap.
func refresh() -> void:
	for kind: InputBindings.Kind in _slots:
		var button: Button = _slots[kind]
		var usable: bool = kind == InputBindings.Kind.PAD or not action in InputBindings.PAD_ONLY
		button.disabled = not usable
		# Dimmed like a disabled options row, frame and all.
		button.self_modulate = Color.WHITE if usable else Color(1, 1, 1, 0.35)
		if _is_listening(kind):
			button.text = _LISTENING_TEXT
		else:
			button.text = InputBindings.slot_label(action, kind) if usable else InputBindings.UNBOUND_LABEL


func _on_slot_pressed(kind: InputBindings.Kind) -> void:
	if _is_listening(kind):
		InputManager.cancel_listening()
		return
	InputManager.listen_for_binding(action, kind)
	refresh()


func _on_binding_captured(for_action: StringName, kind: InputBindings.Kind, event: InputEvent) -> void:
	if for_action != action:
		return
	var changes: Dictionary[StringName, Array] = InputBindings.plan_bind(action, kind, event)
	for changed: StringName in changes:
		OptionsSettings.set_option(InputBindings.option_key(changed), changes[changed])
	refresh()


func _on_binding_cancelled(for_action: StringName, _kind: InputBindings.Kind) -> void:
	if for_action == action:
		refresh()


func _is_listening(kind: InputBindings.Kind) -> bool:
	return InputManager.listening_for() == [action, kind]


func _stop_if_hidden() -> void:
	if not is_visible_in_tree():
		_stop_listening_here()


func _stop_listening_here() -> void:
	if InputManager.is_listening() and InputManager.listening_for()[0] == action:
		InputManager.cancel_listening()
