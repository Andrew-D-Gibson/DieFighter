extends Sprite2D

var default_cursor_texture: Texture2D = preload("uid://dm4or0suv2f7l")
var info_cursor_texture: Texture2D = preload("uid://p42b6jtcwu2x")

var current_clickable: Clickable = null
var cursor_state: String = "default"  # "default" or "info"

func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	_on_hover_delay_reset()
	show()
	
	# Connect to the existing events system
	Events.mouse_clickable_for_info.connect(_set_cursor_icon)
	Events.set_current_clickable.connect(set_current_clickable)
	
	
func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()


func _set_cursor_icon(clickable_for_info: bool) -> void:
	if clickable_for_info:
		texture = info_cursor_texture
		cursor_state = "info"
	else:
		texture = default_cursor_texture
		cursor_state = "default"


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
	texture = info_cursor_texture
	offset = Vector2(-3,-3)
	cursor_state = "info"


func _on_hover_delay_reset() -> void:
	texture = default_cursor_texture
	offset = Vector2(0,0)
	cursor_state = "default"
