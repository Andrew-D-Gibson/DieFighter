extends Node2D

var main_game_scene: String = "uid://deisauteocrjl"

func _ready() -> void:
	ResourceLoader.load_threaded_request(main_game_scene)
	
	
func _switch_to_next_scene() -> void:
	var status := ResourceLoader.load_threaded_get_status(main_game_scene)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var resource := ResourceLoader.load_threaded_get(main_game_scene)
		if resource is PackedScene:
			get_tree().change_scene_to_packed(resource)

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Failed to load main game scene")
	

func _input(event: InputEvent) -> void:
	# Handle skipping the cutscene
	if event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and \
	event.pressed:
		_switch_to_next_scene()
