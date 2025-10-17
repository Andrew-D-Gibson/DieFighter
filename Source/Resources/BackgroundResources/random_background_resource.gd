class_name RandomBackgroundResource
extends Resource

@export_category('Random Background Pool')
@export var eligible_backgrounds: Array[BackgroundResource] = []

@export_category('Random Selection Settings')
@export var reselect_on_scenario_load: bool = true
@export var reselect_on_manual_background_change: bool = false

var current_selected_background: BackgroundResource

func get_random_background() -> BackgroundResource:
	if eligible_backgrounds.size() == 0:
		push_error("RandomBackgroundResource: No eligible backgrounds defined!")
		return null
	
	# Select a random background from the pool
	var random_index: int = randi() % eligible_backgrounds.size()
	current_selected_background = eligible_backgrounds[random_index]
	
	return current_selected_background

func get_current_background() -> BackgroundResource:
	return current_selected_background

func has_selected_background() -> bool:
	return current_selected_background != null
