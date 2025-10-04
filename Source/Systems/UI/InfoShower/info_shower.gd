extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	self.visible = false
	
	Events.show_info.connect(_show_info)
	Events.close_info.connect(hide)
	

func _show_info(info: InfoResource) -> void:
	if not info:
		return
		
	%TitleLabel.text = Utils.format_text(info.title_label_text, 1)
	%TopLabel.text = Utils.format_text(info.top_label_text, 1)
	%TextureDisplay.texture = info.texture
	%BottomLabel.text = Utils.format_text(info.bottom_label_text, 1)
	%SideLabel.text = Utils.format_text(info.side_label_text, 1)
	self.visible = true





func _on_screen_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		Events.info_graphic_closed.emit()
		hide()
