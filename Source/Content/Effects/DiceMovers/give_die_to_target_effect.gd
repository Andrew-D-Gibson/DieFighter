class_name GiveDieToTargetEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no activator die
	if not effect_variables.activator_die:
		return
		
	# Put the die in the "holding" state
	effect_variables.activator_die.draggable.state = Draggable.DragState.ENEMY_HOLDING
		
	# If there's no target give the die to the player as a failsafe measure
	if len(effect_variables.targets) == 0 or not effect_variables.targets[0]:
		Globals.player.dice_manager.add(effect_variables.activator_die, false)
		return
		
	# If the target is dead, try to give it to a random enemy
	if effect_variables.targets[0].health.health <= 0:
		var enemies = Globals.enemy_manager.get_alive_enemies()
		if len(enemies) == 0:
			Globals.player.dice_manager.add(effect_variables.activator_die)
		else:
			enemies.pick_random().dice_manager.add(effect_variables.activator_die)
		return
	
	
	# If the player is giving the dice back to itself, re-roll the dice then go
	if effect_variables.activator_die.host_queue == Globals.player.dice_manager\
	and effect_variables.targets[0] is Player:
		await effect_variables.activator_die.reroll_with_tween()
	
	# Give the die to the target's dice queue, and don't randomize
	# Enemies don't randomize dice, and the player will handle that at 
	# the start of their turn
	effect_variables.targets[0].dice_manager.add(effect_variables.activator_die)
