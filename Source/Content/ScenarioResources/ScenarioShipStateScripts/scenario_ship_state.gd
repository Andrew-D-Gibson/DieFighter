class_name ScenarioShipState
extends ScenarioShipStateBase

@export_multiline var dialogue: String
@export var faction: ScenarioManager.Faction
@export var attitude: Enemy.Attitude
@export var effects_on_enter: EffectChain

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


## The line the ship says on entering this state, in the current language.
## Empty for a silent state.
func display_dialogue() -> String:
	return ContentText.text(self, &"dialogue")


func _content_text_prefix() -> String:
	return "SHIP_STATE"


## State files repeat their names across encounters (hauler_betrayed.tres in
## three events), so their keys name the encounter's folder too.
func _content_text_folder_in_key() -> bool:
	return true


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"dialogue", "DIALOGUE",
			"A line an NPC ship says in a speech bubble when an encounter changes its mood (it is hailed, betrayed, paid, robbed). Spoken, casual, short: the bubble holds about 50 characters.", 50),
	]
