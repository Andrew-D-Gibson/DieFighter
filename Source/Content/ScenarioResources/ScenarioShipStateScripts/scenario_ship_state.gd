class_name ScenarioShipState
extends ScenarioShipStateBase

@export_multiline var dialogue: String
## Said instead of dialogue to a player who already knows Fate's secret, from
## an earlier run (FateLedger.knew_secret): the Inbound pilgrim's "You've seen
## the front." Empty for a state that says the same to everyone.
@export_multiline var fate_knowing_dialogue: String
## Said instead of either to a player who has had a Become Fate ending in an
## earlier run (RECKONING_ENDINGS.md §8): the pilgrim's "...Oh. It's you."
## Empty for a state that says nothing new to them.
@export_multiline var become_fate_dialogue: String
## What the player did to reach this state, for the "Carved by" line of the
## Fate's Die face its effects_on_enter carves: a short past-tense sentence
## ("Saved a civilian from pirates."). Empty for a state that carves nothing.
@export_multiline var fate_carve_note: String
@export var faction: ScenarioManager.Faction
@export var attitude: Enemy.Attitude
@export var effects_on_enter: EffectChain

@export var transitions: Dictionary[ScenarioManager.ScenarioEvent, ScenarioShipStateBase]

@export_category("Faction Memory")
## What reaching this state means to the fleet: the shop the player shot up,
## the Picket they relieved. Recorded in the run's FactionLedger as the ship
## enters the state and its effects play (opening states included, when the
## ship lands), and never again for a ship a Continue puts back here.
@export var deeds: Array[FactionDeed] = []

## The ship takes no part in the fight while in this state: every intent on
## its table does nothing (Enemy.silence_face), so a die it's handed is spent
## on nothing and comes home. For a ship that has surrendered.
@export var holds_fire: bool = false

## The share of its max hull at or below which a hit makes this ship hear
## HULL_CRITICAL. Only read when this state has a HULL_CRITICAL transition.
@export_range(0.05, 0.95, 0.05) var critical_hull_fraction: float = 0.3

## Entering this state signs the ship on as the player's escort: it leaves
## with them and rides along through the next fights (EscortKeeper). Like
## deeds, it happens as the effects play, never for a ship a Continue puts
## back here.
@export var escort: EscortResource


## The state this ship moves to on [param event]: itself when the event leads
## nowhere. [param ship_faction] is the ship's own faction, for a standing
## branch on the way that asks about it.
func handle_scenario_event(event: ScenarioManager.ScenarioEvent, ship_faction: FactionIdentity = null) -> ScenarioShipState:
	if not transitions.has(event) or transitions[event] == null:
		return self
	var next_state: ScenarioShipState = transitions[event].resolve(ship_faction)
	if next_state == null:
		push_warning("ScenarioShipState: %s leads to a node that picks no state; staying put." % [
			ScenarioManager.ScenarioEvent.keys()[event]])
		return self
	return next_state


func resolve(_ship_faction: FactionIdentity) -> ScenarioShipState:
	return self


func next_states() -> Array[ScenarioShipStateBase]:
	var next: Array[ScenarioShipStateBase] = []
	for state: ScenarioShipStateBase in transitions.values():
		if state:
			next.append(state)
	return next


## The line the ship says on entering this state, in the current language.
## Empty for a silent state.
func display_dialogue() -> String:
	if not become_fate_dialogue.is_empty() and CollectionManager.fate_endings("become_fate") > 0:
		return ContentText.text(self, &"become_fate_dialogue")
	if not fate_knowing_dialogue.is_empty() and Globals.fate_ledger and Globals.fate_ledger.knew_secret:
		return ContentText.text(self, &"fate_knowing_dialogue")
	return ContentText.text(self, &"dialogue")


## What the player did to carve a face by entering this state, in the current
## language. Empty when the state doesn't say.
func display_fate_carve_note() -> String:
	return ContentText.text(self, &"fate_carve_note")


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
		ContentText.Field.new(&"fate_knowing_dialogue", "FATE_KNOWING_DIALOGUE",
			"The same line, said instead to a player who has already learned the game's secret (that the fleet is being herded into a second black hole) in an earlier run. Same bubble: about 50 characters.", 50),
		ContentText.Field.new(&"fate_carve_note", "FATE_CARVE_NOTE",
			"What the player did in this encounter to carve a face into Fate's Die, shown after \"Carved by:\" on that face in the die's info panel. A short past-tense sentence with a full stop, about 40 characters.", 60),
		ContentText.Field.new(&"become_fate_dialogue", "BECOME_FATE_DIALOGUE",
			"The same line, said instead to a player who has had the Become Fate ending in an earlier run: they destroyed their own reflection inside the black hole, were taken by it, and the game looped back to the start. The speaker recognises the player as part of the hole now. Same bubble: about 50 characters.", 50),
	]
