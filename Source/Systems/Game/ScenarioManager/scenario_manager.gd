class_name ScenarioManager
extends Node2D

enum ScenarioEvent {
	PLAYER_ATTACKED_PIRATE,
	PLAYER_ATTACKED_CIVILIAN,
	
	PLAYER_LEFT_SCENARIO,
	
	COMBAT_ENDED,
	PIRATES_DEFEATED,
	CIVILIANS_DEFEATED,
}

enum Faction {
	PIRATE,
	CIVILIAN
}


func _ready() -> void:
	Globals.scenario_manager = self
	
	Events.load_scenario.connect(_load_scenario)
	Events.player_attacked_ship.connect(_handle_attack)
	Events.enemy_died.connect(_handle_enemy_death)
	
	Events.combat_finished.connect(func() -> void:
		Events.scenario_event.emit(ScenarioEvent.COMBAT_ENDED)
	)
	
	
func _load_scenario(scenario: ScenarioResource) -> void:
	# Set the background
	if scenario.background_resource:
		Events.set_background.emit(scenario.background_resource)
		
	# Spawn the starting ships
	if len(scenario.starting_enemies) > 0:
		Globals.enemy_manager.spawn_enemies(scenario.starting_enemies)


func _handle_attack(ship: Enemy, ship_faction: ScenarioManager.Faction):
	match ship_faction:
		Faction.PIRATE:
			Events.scenario_event.emit(ScenarioEvent.PLAYER_ATTACKED_PIRATE)
	
		Faction.CIVILIAN:
			Events.scenario_event.emit(ScenarioEvent.PLAYER_ATTACKED_CIVILIAN)


## Checks if a faction has been completely wiped out,
## then emits the corresponding signal if necessary
func _handle_enemy_death(faction: Faction) -> void:
	var other_faction_ships: Array[Enemy] = Globals.enemy_manager.get_faction_ships(faction)
	if len(other_faction_ships) == 0:
		match faction:
			Faction.PIRATE:
				Events.scenario_event.emit(ScenarioEvent.PIRATES_DEFEATED)
				
			Faction.CIVILIAN:
				Events.scenario_event.emit(ScenarioEvent.CIVILIANS_DEFEATED)
