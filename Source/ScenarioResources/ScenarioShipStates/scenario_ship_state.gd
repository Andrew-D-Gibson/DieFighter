class_name ScenarioShipState
extends ScenarioShipStateBase

enum scenario_event {
	PLAYER_ATTACKED_PIRATE,
	PLAYER_ATTACKED_CIVILIAN,
	
	PLAYER_LEFT_SCENARIO,
}

@export var dialogue: String
@export var attitude: Enemy.Attitude
@export var effects_on_enter: Array[EffectResource]

@export var transitions: Dictionary[scenario_event, ScenarioShipStateBase]
