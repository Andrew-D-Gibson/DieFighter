extends Camera2D

var ssCount = 1

func _ready() -> void:
	var dir := DirAccess.open("res://screenshots")
	if dir == null:
		dir = DirAccess.open("res://")
		dir.make_dir("screenshots")
	else:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var max_num = 0
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("ss") and file_name.ends_with(".png"):
				var num_text = file_name.substr(2, file_name.length() - 6) # Remove "ss" and ".png"
				var num = int(num_text)
				if num > max_num:
					max_num = num
			file_name = dir.get_next()
		
		dir.list_dir_end()
		
		ssCount = max_num + 1
	

func screenshot() -> void:
	await RenderingServer.frame_post_draw
	
	var viewport := get_viewport()
	var img := viewport.get_texture().get_image()
	img.save_png("res://screenshots/ss" + str(ssCount) + ".png")
	ssCount += 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		screenshot()
