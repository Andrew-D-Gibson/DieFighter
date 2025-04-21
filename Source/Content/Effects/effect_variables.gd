class_name EffectVariables
extends RefCounted

var actor: Node = null
var effect_source: Node = null
var targets = []
var activator_die: Dice = null

# Damage calculation system
var base_amount: int = 0
var amount_modifiers: Array[Callable] = []

func calculate_final_amount() -> int:
	var final_amount = base_amount
	for modifier in amount_modifiers:
		final_amount = modifier.call(final_amount)
	return final_amount

func add_amount_modifier(modifier: Callable) -> void:
	amount_modifiers.append(modifier)

func clear_amount_modifiers() -> void:
	amount_modifiers.clear()
