class_name EffectVariables
extends RefCounted

## Actor should be the player or the enemy ship triggering the effect
var actor: Node = null

## Effect source should be the tile activated, or the enemy ship using the die
var effect_source: Node = null

var targets: Array[Node] = []
var activator_die: Dice = null

## The number of times to trigger the whole effect chain
var repetitions: int = 1

# Amount (damage/shields etc.) calculation system
var base_amount: int = 0
var amount_modifiers: Array[Callable] = []


func calculate_final_amount() -> int:
	if not base_amount:
		base_amount = 0
		
	var final_amount: int = base_amount
	for modifier: Callable in amount_modifiers:
		final_amount = modifier.call(final_amount)
	return final_amount


## Calculate final amount with global modifiers applied
func calculate_final_amount_with_global_modifiers(category: int) -> int:
	var base = calculate_final_amount()
	
	if Globals.modifier_manager:
		return Globals.modifier_manager.apply_modifiers_to_amount(category, base, self)
	
	return base


func add_amount_modifier(modifier: Callable) -> void:
	amount_modifiers.append(modifier)


func clear_amount_modifiers() -> void:
	amount_modifiers.clear()
