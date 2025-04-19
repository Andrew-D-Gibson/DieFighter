class_name ScenarioShipState
extends ScenarioShipStateBase

@export var dialogue: String
@export var faction: ScenarioManager.Faction
@export var attitude: Enemy.Attitude
@export var effects_on_enter: Array[Effect]

@export var transitions: Dictionary[ScenarioManager.ScenarioEvent, ScenarioShipStateBase]


func handle_scenario_event(event: ScenarioManager.ScenarioEvent) -> ScenarioShipState:
	if transitions.has(event):
		var next_state: ScenarioShipStateBase = transitions[event]
		
		# If the next state is a transition state, use it to get the 
		# next state
		if next_state is ScenarioShipStateProbabilityTransition:
			next_state = next_state.get_next_state_from_probabilities()
			
		return next_state
		
	# If we don't transition on this event, maintain the current state
	return self
