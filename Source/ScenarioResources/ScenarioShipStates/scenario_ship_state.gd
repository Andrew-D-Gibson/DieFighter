class_name ScenarioShipState
extends ScenarioShipStateBase

@export var dialogue: String
@export var faction: ScenarioManager.faction
@export var attitude: Enemy.Attitude
@export var effects_on_enter: Array[EffectResource]

@export var transitions: Dictionary[ScenarioManager.scenario_event, ScenarioShipStateBase]


func handle_scenario_event(event: ScenarioManager.scenario_event) -> ScenarioShipState:
	if transitions.has(event):
		var next_state: ScenarioShipStateBase = transitions[event]
		
		# If the next state is a transition state, use it to get the 
		# next state
		if next_state is ScenarioShipStateProbabilityTransition:
			next_state = next_state.get_next_state_from_probabilities()
			
		return next_state
		
	# If we don't transition on this event, maintain the current state
	return self
