class_name ChangeActivatorValueEffect
extends Effect

@export var new_value: int 
@export var offset_from_original_value: bool = false

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		printerr("ChangeActivatorToValueEffect doesn't have an activator die!")
		return
		
	if not new_value:
		printerr("ChangeActivatorToValueEffect doesn't have a value set!")
		return
	
	if offset_from_original_value:
		# Change the amount, neglecting positive or negative
		# This is so that a +2 modifier to a "subtact 2 value" goes to
		# subtract 4, not subtract 0
		effect_variables.base_amount = abs(new_value)
		var final_amount: int = effect_variables.calculate_final_amount()
		
		# Re-introduce the positive or negative from the expected effect
		final_amount *= sign(new_value)
	
		await effect_variables.activator_die.reroll_with_tween(
			effect_variables.activator_die.value + final_amount
		)
	else:
		await effect_variables.activator_die.reroll_with_tween(
			new_value
		)
