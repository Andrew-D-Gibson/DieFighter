extends Effect

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no activator die
	if not effect_variables.activator_die:
		return
		
	# Remove the die from its source's dice queue
	effect_variables.source.dice_queue.remove(effect_variables.activator_die)
		
	# If there's no target, give the die to the player
	# as a failsafe measure
	if len(effect_variables.targets) == 0:
		Globals.player.dice_queue.add(effect_variables.activator_die)
	
	# Give the die to the target's dice queue, and don't randomize
	# Enemies don't randomize dice, and the player will handle that at 
	# the start of their turn
	effect_variables.targets[0].dice_queue.add(effect_variables.activator_die, true)
