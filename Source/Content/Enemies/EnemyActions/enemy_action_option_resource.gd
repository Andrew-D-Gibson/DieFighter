class_name EnemyActionOptionResource
extends Resource

@export var base_action: EnemyActionResource
@export var weight: float = 1.0
@export var min_amount: int = 0
@export var max_amount: int = 0
@export var force_include: bool = false

## Every one must hold for this option to be rolled at all, force_include
## included. An action that acts on another ship already needs one to exist;
## these are for anything more particular.
@export var conditions: Array[EnemyActionCondition] = []

## Scale [member weight] while the board looks a certain way.
@export var situational_weights: Array[EnemyActionWeightRule] = []

var amount: int = 0

	
func get_action() -> EnemyActionResource:
	# base_action.duplicate(true) already deep-duplicates effect_chain
	# (and its effects) for us, so v2 actions need nothing further here —
	# their amount is applied at play-time via context.enemy_intent_amount.
	var action: EnemyActionResource = base_action.duplicate(true)

	# Randomly set the strength of the effect, then scale it by how deep into
	# the run the player is. This is the only place a turn's amounts are rolled,
	# so it's the one place run difficulty needs to touch enemy damage.
	amount = RNGManager.randi_range(RNGManager.Bucket.ENEMY_AI, min_amount, max_amount)
	if amount != 0 and Globals.state_manager:
		amount = maxi(1, ceili(amount * Globals.state_manager.get_damage_multiplier()))
	action.intent_amount = amount

	return action


func conditions_met(situation: EnemyActionSituation) -> bool:
	for condition: EnemyActionCondition in conditions:
		if condition and not condition.is_met(situation):
			return false
	return true


## [member weight] as this situation scales it.
func weight_in(situation: EnemyActionSituation) -> float:
	var scaled: float = weight
	for rule: EnemyActionWeightRule in situational_weights:
		if rule:
			scaled *= rule.factor(situation)
	return scaled
