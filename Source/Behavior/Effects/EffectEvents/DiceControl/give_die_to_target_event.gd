class_name GiveDieToTargetEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	activator_die.draggable.state = Draggable.DragState.ENEMY_HOLDING

	# No valid target — reroll and return to player.
	if targets.is_empty() or not is_instance_valid(targets[0]):
		await activator_die.reroll_with_tween()
		if is_instance_valid(Globals.player):
			Globals.player.dice_manager.add(activator_die)
		return

	var target: Node = targets[0]

	# Target is dead — give to a random alive enemy, or the player as fallback.
	if target.health.health <= 0:
		var alive_enemies: Array = Globals.enemy_manager.get_alive_enemies()
		if alive_enemies.is_empty():
			if is_instance_valid(Globals.player):
				Globals.player.dice_manager.add(activator_die)
		else:
			RNGManager.pick_random(RNGManager.Bucket.TARGETING, alive_enemies).dice_manager.add(activator_die)
		return

	target.dice_manager.add(activator_die)
