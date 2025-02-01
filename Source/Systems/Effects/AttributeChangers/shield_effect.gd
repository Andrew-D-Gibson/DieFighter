extends Effect

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0:
		return
		
	# If not given an amount (amount is 0),
	# use the activator die's value
	if amount == 0 and effect_variables.activator_die:
		amount = effect_variables.activator_die.value
	
	effect_variables.targets[0].health.change_shield(amount)
