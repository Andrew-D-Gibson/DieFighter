extends Effect

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no activator die
	if not effect_variables.activator_die:
		return
		
	# Remove the die from its source's dice queue
	effect_variables.source.dice_queue.remove(effect_variables.activator_die)
		
	# If there's no target give the die to the player as a failsafe measure
	if len(effect_variables.targets) == 0 or not effect_variables.targets[0]:
		Globals.player.dice_queue.add(effect_variables.activator_die, true)
		return
		
	# If the target is dead, try to give it to a random enemy
	if effect_variables.targets[0].health.health <= 0:
		var enemies = Globals.enemy_manager.get_alive_enemies()
		if len(enemies) == 0:
			Globals.player.dice_queue.add(effect_variables.activator_die, true)
		else:
			enemies.pick_random().dice_queue.add(effect_variables.activator_die, true)
		return
	
	# Give the die to the target's dice queue, and don't randomize
	# Enemies don't randomize dice, and the player will handle that at 
	# the start of their turn
	effect_variables.targets[0].dice_queue.add(effect_variables.activator_die, true)
