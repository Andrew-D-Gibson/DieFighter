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
	
	# Create a new array for the effect chain
	action.effect_chain = []
	
	# Duplicate each effect and add it to the new chain
	# This is needed due to how Godot handles duplicating Arrays of Resources
	for effect in base_action.effect_chain:
		var new_effect = effect.duplicate()
		if new_effect.primary_effect:
			new_effect.amount = amount
			
		action.effect_chain.append(new_effect)
			
	return action
