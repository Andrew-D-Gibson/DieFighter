class_name ScenarioManager
extends Node2D

enum scenario_event {
	PLAYER_ATTACKED_PIRATE,
	PLAYER_ATTACKED_CIVILIAN,
	
	PLAYER_LEFT_SCENARIO,
	
	COMBAT_ENDED,
}

enum faction {
	PIRATE,
	CIVILIAN
}


func _ready() -> void:
	Globals.scenario_manager = self
	Events.load_scenario.connect(_load_scenario)
	Events.player_attacked_ship.connect(_handle_attack)
	Events.combat_finished.connect(func():
		Events.scenario_event.emit(scenario_event.COMBAT_ENDED)
	)
	
	
func _load_scenario(scenario: ScenarioResource) -> void:
	# Set the background
	if scenario.background_resource:
		Events.set_background.emit(scenario.background_resource)
		
	# Spawn the starting ships
	if len(scenario.starting_enemies) > 0:
		Globals.enemy_manager.spawn_enemies(scenario.starting_enemies)


func _handle_attack(ship: Enemy, ship_faction: ScenarioManager.faction):
	match ship_faction:
		faction.PIRATE:
			Events.scenario_event.emit(scenario_event.PLAYER_ATTACKED_PIRATE)
	
		faction.CIVILIAN:
			Events.scenario_event.emit(scenario_event.PLAYER_ATTACKED_CIVILIAN)
