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
	amount = Enemy.rng.randi_range(min_amount, max_amount)
	action.intent_amount = amount

	# Legacy v1 EffectChain support: patch primary effect amounts.
	# Skipped for actions that only use effect_chain_v2.
	if base_action.effect_chain:
		action.effect_chain = base_action.effect_chain.duplicate(true)

		# Create a new effects array with duplicated Effect objects
		var duplicated_effects: Array[Effect] = []
		for effect: Effect in base_action.effect_chain.effects:
			var duplicated_effect: Effect = effect.duplicate(true)
			if duplicated_effect.primary_effect:
				duplicated_effect.amount = amount
			duplicated_effects.append(duplicated_effect)

		# Assign the duplicated effects to the new chain
		action.effect_chain.effects = duplicated_effects

	return action
