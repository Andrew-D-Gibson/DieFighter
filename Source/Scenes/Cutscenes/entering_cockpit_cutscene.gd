extends Node2D

var main_game_scene: String = "uid://deisauteocrjl"

func _ready() -> void:
	SceneLoader.request(main_game_scene)
	
	
func _switch_to_next_scene() -> void:
	SceneLoader.switch_to(get_tree(), main_game_scene)
	

func _input(event: InputEvent) -> void:
	# Handle skipping the cutscene
	if event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and \
	event.pressed:
		_switch_to_next_scene()
