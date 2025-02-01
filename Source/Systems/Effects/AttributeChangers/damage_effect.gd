extends Effect

func play(effect_variables: EffectVariables) -> void:
	# If not given an amount (amount is 0),
	# use the activator die's value
	if amount == 0 and effect_variables.activator_die:
		amount = effect_variables.activator_die.value
	
	if len(effect_variables.targets) > 0:
		effect_variables.targets[0].health.take_damage(amount)
