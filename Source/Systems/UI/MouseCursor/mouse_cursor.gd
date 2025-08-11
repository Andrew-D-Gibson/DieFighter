extends Sprite2D

var default_cursor_texture: Texture2D = preload("uid://dm4or0suv2f7l")
var info_cursor_texture: Texture2D = preload("uid://p42b6jtcwu2x")

func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	texture = default_cursor_texture
	show()
	
	
func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()


func _set_cursor_icon(clickable_for_info: bool) -> void:
	if clickable_for_info:
		texture = info_cursor_texture
	else:
		texture = default_cursor_texture
