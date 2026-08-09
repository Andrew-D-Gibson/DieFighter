class_name EnemyActionOptionResource
extends Resource

@export var base_action: EnemyActionResource
@export var weight: float = 1.0
@export var min_amount: int = 0
@export var max_amount: int = 0
@export var force_include: bool = false

var amount: int = 0

	
func get_action() -> EnemyActionResource:
	# base_action.duplicate(true) already deep-duplicates effect_chain_v2
	# (and its effects) for us, so v2 actions need nothing further here —
	# their amount is applied at play-time via context.enemy_intent_amount.
	var action: EnemyActionResource = base_action.duplicate(true)

	# Randomly set the strength of the effect
	amount = RNGManager.randi_range(RNGManager.Bucket.ENEMY_AI, min_amount, max_amount)
	action.intent_amount = amount

	return action
