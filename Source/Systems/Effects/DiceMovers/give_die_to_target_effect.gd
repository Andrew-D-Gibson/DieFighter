extends Effect

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0:
		return
		
	# Don't do anything if there's no activator die
	if not effect_variables.activator_die:
		return

	# Give the die to the target's dice queue
	effect_variables.targets[0].dice_queue.add(effect_variables.activator_die, true)
