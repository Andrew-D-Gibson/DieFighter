class_name ShieldEffect
extends Effect

@export var amount: int = 0

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0:
		return
		
	# If not given an amount (amount is 0),
	# use the activator die's value
	if amount == 0 and effect_variables.activator_die:
		effect_variables.base_amount = effect_variables.activator_die.value
	else:
		effect_variables.base_amount = amount
		
	# Calculate final amount after all modifiers
	var final_amount = effect_variables.calculate_final_amount()
		
	effect_variables.targets[0].health.change_shields(final_amount)
