class_name Utils
extends RefCounted

## Disconnects all the callables that have been attached to a particular signal
static func disconnect_all_callables(signal_to_disconnect: Signal) -> void:
	for connection: Dictionary in signal_to_disconnect.get_connections():
		signal_to_disconnect.disconnect(connection['callable'])


static func array_while_excluding(array: Array, elements_to_exclude: Array) -> Array:
	var array_without_excluded_elements: Array = array.filter(
		func(element) -> bool:
			return not elements_to_exclude.has(element)
	)
	return array_without_excluded_elements


static var dice_image_paths: Array[String] = [
	"res://Assets/Textures/Dice/Holographic/dice_blank.png",
	"res://Assets/Textures/Dice/Holographic/dice_1.png",
	"res://Assets/Textures/Dice/Holographic/dice_2.png",
	"res://Assets/Textures/Dice/Holographic/dice_3.png",
	"res://Assets/Textures/Dice/Holographic/dice_4.png",
	"res://Assets/Textures/Dice/Holographic/dice_5.png",
	"res://Assets/Textures/Dice/Holographic/dice_6.png"
]

static var info_cursor_image_path: String = "res://Assets/Textures/UI/MouseCursors/info_cursor_raw.png"


static func format_text(text: String, scale: int = 6) -> String:
	# Change colors to match the palette
	text = text.replace('=red', '=#' + Globals.red.to_html(false))
	text = text.replace('=blue', '=#' + Globals.blue.to_html(false))
	text = text.replace('=green', '=#' + Globals.green.to_html(false))
	text = text.replace('=yellow', '=#' + Globals.yellow.to_html(false))
	text = text.replace('=purple', '=#' + Globals.purple.to_html(false))
	text = text.replace('=orange', '=#' + Globals.orange.to_html(false))
	
	# Add dice images to replace numbers
	var image_size = 72 / scale
	text = text.replace('(die_blank)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[0] + '[/img]')
	text = text.replace('(die_1)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[1] + '[/img]')
	text = text.replace('(die_2)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[2] + '[/img]')
	text = text.replace('(die_3)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[3] + '[/img]')
	text = text.replace('(die_4)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[4] + '[/img]')
	text = text.replace('(die_5)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[5] + '[/img]')
	text = text.replace('(die_6)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[6] + '[/img]')
	
	#text = text.replace('(info_cursor)', '[img=top,bottom {' + str(image_size) + '}x{' + str(image_size) + '}]' + info_cursor_image_path + '[/img]')

	return text


static func strip_bbcode_tags(text: String) -> String:
	var regex := RegEx.new()
	# This regex matches anything like [tag] or [tag=param]
	regex.compile(r"\[/?[^\]]+\]")
	return regex.sub(text, "", true)


static func slice_texture_right(sprite: Texture2D, pixels: int) -> Texture2D:
	if not sprite:
		push_error("No sprite provided")
		return null
	
	# Get the sprite's image data
	var image: Image = sprite.get_image()
	var width := image.get_width()
	var height := image.get_height()

	# Clamp N to valid range
	pixels = clamp(pixels, 0, width)

	# Crop to the rightmost N pixels
	var cropped_image := image.get_region(Rect2(width - pixels, 0, pixels, height))

	# Convert cropped Image back to Texture2D
	var new_texture := ImageTexture.create_from_image(cropped_image)
	return new_texture
