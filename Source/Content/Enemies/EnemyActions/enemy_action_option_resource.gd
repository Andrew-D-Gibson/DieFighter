class_name EnemyActionOptionResource
extends Resource

@export var base_action: EnemyActionResource
@export var weight: float = 1.0
@export var min_amount: int = 0
@export var max_amount: int = 0
@export var force_include: bool = false

var amount: int = 0

	
func get_action() -> EnemyActionResource:
	var action: EnemyActionResource = base_action.duplicate()
	
	# Randomly set the strength of the effect
	amount = randi_range(min_amount, max_amount)
	action.intent_amount = str(amount) if amount != 0 else ''
	
	# Duplicate the EffectChain resource
	action.effect_chain = base_action.effect_chain.duplicate()
	
	# Set amount for primary effects in the duplicated chain
	for effect: Effect in action.effect_chain.effects:
		if effect.primary_effect:
			effect.amount = amount
	
	return action
