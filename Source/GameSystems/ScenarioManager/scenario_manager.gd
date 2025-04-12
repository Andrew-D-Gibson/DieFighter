class_name ScenarioManager
extends Node2D


func _ready() -> void:
	Globals.scenario_manager = self
	Events.load_scenario.connect(_load_scenario)
	
	
func _load_scenario(scenario: ScenarioResource) -> void:
	# Set the background
	if scenario.background_resource:
		Events.set_background.emit(scenario.background_resource)
		
	# Spawn the starting ships
	if len(scenario.starting_enemies) > 0:
		Globals.enemy_manager.spawn_enemies(scenario.starting_enemies)
