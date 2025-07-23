class_name PauseMenu
extends Node2D

@export var main_menu_scene: PackedScene


func _on_item_hover() -> void:
	Events.play_sound.emit('tile_dropped')


func _on_options_button_pressed() -> void:
	pass
	
	
func _on_options_button_mouse_entered() -> void:
	_on_item_hover()
	%OptionsLabel.add_theme_color_override('default_color', Globals.purple)
	%OptionsLabel.text = '[wave amp=8.0 freq=5.0 connected=1]OPTIONS[/wave]'



func _on_options_button_mouse_exited() -> void:
	%OptionsLabel.add_theme_color_override('default_color', Globals.purple)
	%OptionsLabel.text = 'OPTIONS'
