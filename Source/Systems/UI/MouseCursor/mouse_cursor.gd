extends Sprite2D
## The game's pointer, drawn in place of the OS one so it scales with the
## pixels and follows a controller's virtual cursor too. Cursor icons indicate
## info, custom actions, and held items without automatic text popups.

var default_cursor_texture: Texture2D = preload("uid://dm4or0suv2f7l")
var info_cursor_texture: Texture2D = preload("uid://p42b6jtcwu2x")
const _GRAB_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_cursor_raw.png")
const _GRAB_INFO_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/MouseCursors/grab_info_cursor_raw.png")
## The info cursor is drawn up and left of the pointer, so it sits in the
## circle.
const _INFO_OFFSET: Vector2 = Vector2(-3, -3)
## The fist (the top-left 13x12 of both grab textures) sits a little down and
## right of the pointer: near enough to read as gripping where it points, far
## enough to leave most of the held face (a die's value) in view.
const _GRAB_OFFSET: Vector2 = Vector2(-2, -2)
## The fist is see-through so what shows through it is still the held face.
const _GRAB_ALPHA: float = 0.6

var current_clickable: Clickable = null
## Whether a hovered clickable has waited out its delay: the "i" shows.
var _hover_info: bool = false


func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

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
	if InputManager.control_scheme == InputBindings.ControlScheme.FOCUS and InputManager.cursor.active:
		visible = false
		return
	visible = true

	var hand: Draggable = Draggable.holding()

	if hand:
		var on_info_spot: bool = hand.is_over_info_spot()
		_wear(_GRAB_INFO_TEXTURE if on_info_spot else _GRAB_TEXTURE, _GRAB_OFFSET, _GRAB_ALPHA)
		return

	if is_instance_valid(Globals.map) and Globals.map.is_panning():
		_wear(_GRAB_TEXTURE, _GRAB_OFFSET, _GRAB_ALPHA)
		return

	var acting: Clickable = _acting_clickable()
	if acting and acting.hover_cursor:
		# Drawn like the arrow, its tip on the pointer's spot.
		_wear(acting.hover_cursor, Vector2.ZERO)
	elif _hover_info:
		_wear(info_cursor_texture, _INFO_OFFSET)
	else:
		_wear(default_cursor_texture, Vector2.ZERO)


## The hovered clickable, when it has its own pointer and is live;
## otherwise null. Re-read every frame: a clickable can go dead (a ship's
## comms cut off by a jump) while the pointer rests on it.
func _acting_clickable() -> Clickable:
	if not is_instance_valid(current_clickable):
		return null
	if current_clickable.hover_cursor == null:
		return null
	if not current_clickable.hovered or not current_clickable.input_pickable:
		return null
	return current_clickable


func _wear(cursor_texture: Texture2D, cursor_offset: Vector2, alpha: float = 1.0) -> void:
	texture = cursor_texture
	offset = cursor_offset
	self_modulate.a = alpha


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
