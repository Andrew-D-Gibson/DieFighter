class_name ScenarioManager
extends Node2D

enum ScenarioEvent {
	PLAYER_ATTACKED_PIRATE,
	PLAYER_ATTACKED_CIVILIAN,
	
	PLAYER_LEFT_SCENARIO,
	
	COMBAT_ENDED,
	PIRATES_DEFEATED,
	CIVILIANS_DEFEATED,
	BOSS_DEFEATED,
}

enum Faction {
	PIRATE,
	CIVILIAN,
	BOSS
}

var current_scenario: ScenarioResource


func _ready() -> void:
	Globals.scenario_manager = self
	
	Events.player_attacked_ship.connect(_handle_attack)
	Events.enemy_left.connect(_handle_enemy_leaving)

	Events.combat_finished.connect(func() -> void:
		Events.scenario_event.emit(ScenarioEvent.COMBAT_ENDED)
	)
	Events.load_scenario.connect(
		func(scenario: ScenarioResource) -> void:
			current_scenario = scenario
	)


func _handle_attack(_ship: Enemy, ship_faction: ScenarioManager.Faction) -> void:
	match ship_faction:
		Faction.PIRATE:
			Events.scenario_event.emit(ScenarioEvent.PLAYER_ATTACKED_PIRATE)
	
		Faction.CIVILIAN:
			Events.scenario_event.emit(ScenarioEvent.PLAYER_ATTACKED_CIVILIAN)


## Checks if a faction has been completely wiped out,
## then emits the corresponding signal if necessary
func _handle_enemy_leaving(ship: Enemy, faction: Faction) -> void:
	# Just as an edge case, if the player destroys the shop in a single turn
	# it won't close the normal way, so we close it here
	Events.close_shop.emit()
	
	var other_faction_ships: Array[Enemy] = Globals.enemy_manager.get_faction_ships(faction)
	if ship in other_faction_ships:
		other_faction_ships.erase(ship)
		
	if len(other_faction_ships) == 0:
		if current_scenario.rewards.keys().has(faction):
			Events.spawn_reward.emit(
				ship.global_position, 
				current_scenario.rewards[faction]
			)
			
		match faction:
			Faction.PIRATE:
				Events.scenario_event.emit(ScenarioEvent.PIRATES_DEFEATED)
					
			Faction.CIVILIAN:
				Events.scenario_event.emit(ScenarioEvent.CIVILIANS_DEFEATED)
				
			Faction.BOSS:
				Events.scenario_event.emit(ScenarioEvent.BOSS_DEFEATED)
				
		
