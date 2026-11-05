class_name PauseMenu
extends Node2D


func _ready() -> void:
	Events.toggle_pause_menu.connect(_toggle_pause_menu)
	$VBoxContainer/QuitButton.visible = QuitManager.can_quit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not %OptionsMenu.visible and (event.is_action_pressed(&"cursor_back") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		_toggle_pause_menu()


func _toggle_pause_menu() -> void:
	%OptionsMenu.hide()
	
	if visible:
		hide()
		get_tree().paused = false
	else:
		Events.close_info.emit()
		show()
		get_tree().paused = true


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SceneLoader.MAIN_MENU)


func _on_options_button_pressed() -> void:
	%OptionsMenu.show()


func _on_quit_button_pressed() -> void:
	QuitManager.request_quit()


func _on_wishlist_button_pressed() -> void:
	Utils.open_wishlist()
