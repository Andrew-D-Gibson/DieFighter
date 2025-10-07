extends Control

var texture_final_pos: Vector2 = Vector2(816, 324)

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
	%BottomLabel.text = Utils.format_text(info.bottom_label_text, 1)
	%SideLabel.text = Utils.format_text(info.side_label_text, 1)
	self.visible = true

	%TextureDisplay.texture = info.texture
	%TextureDisplay.modulate.a = 0
	%TweenableTextureDisplay.texture = info.texture
	%TweenableTextureDisplay.show()
	
	var starting_pos: Vector2 = get_global_mouse_position()
	
	var texture_zoom_tween: Tween = get_tree().create_tween()
	texture_zoom_tween.set_parallel()
	var tween_time: float = 0.5	
	texture_zoom_tween.tween_property(
		%TweenableTextureDisplay,
		"scale",
		Vector2(1,1),
		tween_time
	).from(Vector2(0.25,0.25))\
	.set_trans(Tween.TRANS_CUBIC)\
	.set_ease(Tween.EASE_OUT)
	
	texture_zoom_tween.tween_property(
		%TweenableTextureDisplay,
		"position",
		texture_final_pos,
		tween_time
	).from(starting_pos)\
	.set_trans(Tween.TRANS_CUBIC)\
	.set_ease(Tween.EASE_OUT)
	
	await texture_zoom_tween.finished
	%TweenableTextureDisplay.hide()
	%TextureDisplay.modulate.a = 1



func _on_screen_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		Events.info_graphic_closed.emit()
		hide()
