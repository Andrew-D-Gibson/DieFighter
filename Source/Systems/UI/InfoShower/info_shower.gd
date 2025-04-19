extends Control

@export var dice_image_paths: Array[String]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	self.visible = false
	
	Events.show_info.connect(_show_info)
	

func _show_info(info: InfoResource) -> void:
	%TitleLabel.text = info.title_label_text
	%TopLabel.text = _format_text(info.top_label_text)
	%TextureDisplay.texture = info.texture
	%BottomLabel.text = _format_text(info.bottom_label_text)
	self.visible = true


func _format_text(text: String) -> String:
	# Change colors to match the palette
	text = text.replace('red', '#' + Globals.red.to_html(false))
	text = text.replace('blue', '#' + Globals.blue.to_html(false))
	text = text.replace('green', '#' + Globals.green.to_html(false))
	text = text.replace('yellow', '#' + Globals.yellow.to_html(false))
	text = text.replace('purple', '#' + Globals.purple.to_html(false))
	text = text.replace('orange', '#' + Globals.orange.to_html(false))
	
	# Add dice images to replace numbers
	var dice_image_size = 72
	text = text.replace('(die_blank)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[0] + '[/img]')
	text = text.replace('(die_1)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[1] + '[/img]')
	text = text.replace('(die_2)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[2] + '[/img]')
	text = text.replace('(die_3)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[3] + '[/img]')
	text = text.replace('(die_4)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[4] + '[/img]')
	text = text.replace('(die_5)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[5] + '[/img]')
	text = text.replace('(die_6)', '[img={' + str(dice_image_size) + '}x{' + str(dice_image_size) + '}]' + dice_image_paths[6] + '[/img]')
	
	return text


func _on_screen_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		self.visible = false
