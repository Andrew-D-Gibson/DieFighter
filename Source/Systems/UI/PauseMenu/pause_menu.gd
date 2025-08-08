class_name PauseMenu
extends Node2D

var main_menu_file: String = "uid://ccvtlre5vhj7d"


func _ready() -> void:
	Events.toggle_pause_menu.connect(_toggle_pause_menu)


func _toggle_pause_menu() -> void:
	%OptionsMenu.hide()
	
	if visible:
		hide()
		get_tree().paused = false
	else:
		show()
		get_tree().paused = true


func _on_main_menu_button_pressed() -> void:
	_save_game()
	
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_file)
	

func _on_options_button_pressed() -> void:
	%OptionsMenu.show()


func _on_save_and_quit_button_pressed() -> void:
	_save_game()
	get_tree().quit()
	

func _save_game() -> void:
	print('Saving game!')


func _on_wishlist_button_pressed() -> void:
	var url: String = "https://store.steampowered.com/app/3689280/Die_Fighter/"
	OS.shell_open(url)
