extends Sprite2D
## The game's pointer, drawn in place of the OS one so it scales with the
## pixels and follows a controller's virtual cursor too. It shows what a click
## would do: the arrow; an "i" once hovering has something to explain; and a
## closed hand while a die or tile is in hand.
##
## Click placement (Draggable.PlacementMode.CLICK) leaves the button up
## between pick-up and drop, so nothing about the hand says it's still
## holding: the fist does. Clicking a lifted thing again where it was picked
## up puts it back and shows its info, which nothing would ever reveal, so
## while the pointer is on that spot the fist wears an "i" badge, and the first
## few pick-ups each launch spell both clicks out in a line beside it.

var default_cursor_texture: Texture2D = preload("uid://dm4or0suv2f7l")
var info_cursor_texture: Texture2D = preload("uid://p42b6jtcwu2x")
const _GRAB_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_cursor_raw.png")
const _GRAB_INFO_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_info_cursor_raw.png")
## The info cursor is drawn up and left of the pointer, so it sits in the
## circle.
const _INFO_OFFSET: Vector2 = Vector2(-3, -3)
## The held thing follows the pointer, centred on it, so the fist grips its
## lower right corner instead of covering the face the player is placing.
const _GRAB_OFFSET: Vector2 = Vector2(2, 2)

## How many click-mode pick-ups each launch get the hint line. Enough to learn
## both clicks, few enough not to nag.
const CARRY_HINT_PICKUPS: int = 3
## Where the hint line starts, right of the pointer and clear of the fist and
## its badge, in cursor pixels. It flips to the left near the screen's edge.
const _HINT_GAP: Vector2 = Vector2(19, 2)
## How far left of the pointer a flipped hint line ends: clear of the held
## thing, a lifted die or tile being about this wide either side.
const _HINT_FLIPPED_GAP: float = 10.0
const _HINT_OUTLINE: Color = Color("#040217")
## Pick-ups that have shown the hint so far. Static, so it counts across
## scenes for the whole launch.
static var _carry_hints_given: int = 0

var current_clickable: Clickable = null
## Whether a hovered clickable has waited out its delay: the "i" shows.
var _hover_info: bool = false
## What the hand last held, to notice each new pick-up.
var _hand: Draggable = null
## Whether this pick-up is one that shows the hint line.
var _hinting: bool = false
var _hint: Label


func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_hint = _make_hint()
	add_child(_hint)
	_on_hover_delay_reset()
	show()

	# Connect to the existing events system
	Events.set_current_clickable.connect(set_current_clickable)


func _process(_delta: float) -> void:
	# Not get_global_mouse_position(): that's the OS pointer, which may lag a
	# controller's virtual one (InputManager.cursor).
	global_position = get_canvas_transform().affine_inverse() * InputManager.pointer_position(get_viewport())
	_update_look()


## Picks the cursor for this frame. Polled, not signalled: whether a lifted
## thing's info spot is under the pointer changes with every move.
func _update_look() -> void:
	var hand: Draggable = Draggable.holding()
	if hand != _hand:
		_on_hand_changed(hand)

	if hand:
		var on_info_spot: bool = hand.is_over_info_spot()
		_wear(_GRAB_INFO_TEXTURE if on_info_spot else _GRAB_TEXTURE, _GRAB_OFFSET)
		if _hinting:
			_show_hint(tr(&"CURSOR_HINT_CLICK_FOR_INFO") if on_info_spot else tr(&"CURSOR_HINT_CLICK_TO_PLACE"))
	elif _hover_info:
		_wear(info_cursor_texture, _INFO_OFFSET)
	else:
		_wear(default_cursor_texture, Vector2.ZERO)


func _on_hand_changed(hand: Draggable) -> void:
	_hand = hand
	_hinting = false
	_hint.hide()
	# Only click pick-ups: a drag is let go of in one motion and needs no telling.
	if hand and hand.is_carried() and _carry_hints_given < CARRY_HINT_PICKUPS:
		_carry_hints_given += 1
		_hinting = true


func _wear(cursor_texture: Texture2D, cursor_offset: Vector2) -> void:
	texture = cursor_texture
	offset = cursor_offset


func _show_hint(text: String) -> void:
	_hint.text = text
	_hint.show()
	_hint.reset_size()
	# Flipped to the pointer's left when the line would run off the screen.
	var screen_right: float = get_viewport_rect().size.x / global_scale.x
	var pointer_x: float = get_global_transform_with_canvas().origin.x / global_scale.x
	var runs_off: bool = pointer_x + _HINT_GAP.x + _hint.size.x > screen_right
	_hint.position = Vector2(-_HINT_FLIPPED_GAP - _hint.size.x if runs_off else _HINT_GAP.x, _HINT_GAP.y)


func _make_hint() -> Label:
	var hint: Label = Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override(&"font_color", Globals.white)
	# Dark-edged, so it reads over the cockpit, the map and the stars alike.
	hint.add_theme_color_override(&"font_outline_color", _HINT_OUTLINE)
	hint.add_theme_constant_override(&"outline_size", 4)
	hint.hide()
	return hint


func set_current_clickable(clickable: Clickable) -> void:
	# Disconnect from previous clickable if it exists
	if current_clickable:
		_disconnect_from_clickable(current_clickable)

	current_clickable = clickable

	# Connect to new clickable
	if clickable:
		_connect_to_clickable(clickable)
	else:
		_on_hover_delay_reset()


func _connect_to_clickable(clickable: Clickable) -> void:
	if not clickable.hover_delay_completed.is_connected(_on_hover_delay_completed):
		clickable.hover_delay_completed.connect(_on_hover_delay_completed)
	if not clickable.hover_delay_reset.is_connected(_on_hover_delay_reset):
		clickable.hover_delay_reset.connect(_on_hover_delay_reset)
	if not clickable.clicked.is_connected(_on_hover_delay_reset):
		clickable.clicked.connect(_on_hover_delay_reset)


func _disconnect_from_clickable(clickable: Clickable) -> void:
	if clickable.hover_delay_completed.is_connected(_on_hover_delay_completed):
		clickable.hover_delay_completed.disconnect(_on_hover_delay_completed)
	if clickable.hover_delay_reset.is_connected(_on_hover_delay_reset):
		clickable.hover_delay_reset.disconnect(_on_hover_delay_reset)
	if clickable.clicked.is_connected(_on_hover_delay_reset):
		clickable.clicked.disconnect(_on_hover_delay_reset)


func _on_hover_delay_completed() -> void:
	if not Draggable.holding():
		_hover_info = true


func _on_hover_delay_reset() -> void:
	_hover_info = false
