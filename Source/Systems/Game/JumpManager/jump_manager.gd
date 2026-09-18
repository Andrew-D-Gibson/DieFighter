class_name JumpManager
extends Node2D

func _ready() -> void:
	Globals.jump_manager = self
	Globals.map.request_jump_to_scenario.connect(jump_to_scenario)
	
	
## Plays the full hyperspace transition into a scenario: intro animation,
## scenario load, outro, then scenario start.
func jump_to_scenario(scenario: ScenarioResource) -> void:
	Events.jump.emit()
	
	await Globals.background_manager.play_jump_intro()
	await get_tree().create_timer(2).timeout
	Events.load_scenario.emit(scenario)
	await Globals.background_manager.play_jump_outro()
	
	Events.start_scenario.emit()
