class_name LockoutEffectEvent
extends EffectEvent

## The lockout this event is enforcing, so rolling the key (a 2) can lift it.
var lockout_modifier: LockoutModifier


func resolve(engine: ScenarioEngine) -> void:
	if effect_source is not Tile:
		return
		
	if not activator_die:
		return
		
	
	if activator_die.value == 2:
		# Clear the Lockout
		if lockout_modifier:
			engine.remove_modifier(lockout_modifier)
			
			# Give the activator die to a random enemy
			var alive_enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
			
			if alive_enemies.is_empty():
				Globals.player.dice_manager.add(activator_die, true, false)
			else:
				RNGManager.pick_random(RNGManager.Bucket.TARGETING, alive_enemies).dice_manager.add(activator_die)
			
	else:
		# Enforce the Lockout
		var tile: Tile = effect_source as Tile
		tile.dice_queue.remove(activator_die)
		Events.error_text_popup.emit("TILE LOCKED", tile.global_position)
		Globals.player.dice_manager.add(activator_die, true, false)
