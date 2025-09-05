class_name EnemyActionOptionResource
extends Resource

@export var base_action: EnemyActionResource
@export var weight: float = 1.0
@export var min_amount: int = 0
@export var max_amount: int = 0
@export var force_include: bool = false

var amount: int = 0

	
func get_action() -> EnemyActionResource:
	var action: EnemyActionResource = base_action.duplicate(true)
	
	# Randomly set the strength of the effect
	amount = Enemy.rng.randi_range(min_amount, max_amount)
	action.intent_amount = str(amount) if amount != 0 else ''
	
	# Duplicate the EffectChain resource
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
