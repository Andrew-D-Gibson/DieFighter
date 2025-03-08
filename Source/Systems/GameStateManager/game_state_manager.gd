class_name GameStateManager
extends Node2D

enum GameState {
	IN_COMBAT,
	OUT_OF_COMBAT
}

var state: GameState

# This node has to be the last thing loaded in our game, so it can depend
# on all the other components having had their "_ready" called!
func _ready() -> void:
	Globals.state_manager = self
	
	Events.load_encounter.connect(func(encounter: EncounterResource):
		if len(encounter.enemies_to_spawn) > 0:
			state = GameState.IN_COMBAT
		else:
			state = GameState.OUT_OF_COMBAT
		Events.start_encounter.emit()
	)
	
	Events.start_encounter.emit()
	
