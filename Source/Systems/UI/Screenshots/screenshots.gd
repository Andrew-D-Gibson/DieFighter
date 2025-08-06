extends Node2D

var ssCount: int = 1

func _ready() -> void:
	Events.take_screenshot.connect(screenshot)
	
	var dir: DirAccess = DirAccess.open("user://screenshots")
	if dir == null:
		dir = DirAccess.open("user://")
		dir.make_dir("screenshots")
	else:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		var max_num: int = 0
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("ss") and file_name.ends_with(".png"):
				var num_text: String = file_name.substr(2, file_name.length() - 6) # Remove "ss" and ".png"
				var num: int = int(num_text)
				if num > max_num:
					max_num = num
			file_name = dir.get_next()
		
		dir.list_dir_end()
		
		ssCount = max_num + 1
	

func screenshot() -> void:
	await RenderingServer.frame_post_draw
	
	var viewport: Viewport = get_viewport()
	var img: Image = viewport.get_texture().get_image()
	img.save_png("user://screenshots/ss" + str(ssCount) + ".png")
	print("Saved screenshot #", str(ssCount))
	ssCount += 1
