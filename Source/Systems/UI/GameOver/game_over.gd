extends Control

var main_menu_file: String = "uid://ccvtlre5vhj7d"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Events.game_over.connect(show)


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_file)
