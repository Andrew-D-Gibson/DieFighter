class_name GameStateManager
extends Node2D

@export var current_game_save: GameSaveResource

enum GameState {
	IN_COMBAT,
	OUT_OF_COMBAT
}

var state: GameState = GameState.OUT_OF_COMBAT

# This node has to be the last thing loaded in our game
func _ready() -> void:
	Globals.state_manager = self
	Events.combat_finished.connect(func():
		state = GameState.OUT_OF_COMBAT
	)
	
	Events.load_game_save.emit(current_game_save)
	Events.load_scenario.emit(
		current_game_save.sector_scenarios[
			current_game_save.current_scenario_index
		]
	)
	
	Events.start_scenario.emit()
