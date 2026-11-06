class_name LockoutEffectEvent
extends EffectEvent

## The lockout this event is enforcing, so a key (a 1, 2 or 3) can lift it.
var lockout_modifier: LockoutModifier

## How many Feeds brought the die here; see EffectContext.feed_depth.
var feed_depth: int = 0


func resolve(engine: ScenarioEngine) -> void:
	if effect_source is not Tile:
		return
		
	if not activator_die:
		return
		
	
	if LockoutModifier.unlocks(activator_die.value):
		# Clear the Lockout
		if lockout_modifier:
			engine.remove_modifier(lockout_modifier)
			
			# Give the activator die to a random enemy
			var alive_enemies: Array[Enemy] = FateSelf.by_chance(Globals.enemy_manager.get_alive_enemies())
			
			if alive_enemies.is_empty():
				Globals.player.dice_manager.add(activator_die, true, false)
			else:
				RNGManager.pick_random(RNGManager.Bucket.TARGETING, alive_enemies).dice_manager.add(activator_die)
			
	else:
		# Enforce the Lockout
		var tile: Tile = effect_source as Tile
		tile.dice_queue.remove(activator_die)
		Events.error_text_popup.emit(TranslationServer.translate(&"ERROR_TILE_LOCKED"), tile.global_position)
		tile.play_refusal_feedback()
		if feed_depth > 0:
			var give: GiveDieToTargetEvent = GiveDieToTargetEvent.new()
			give.actor = actor
			give.effect_source = effect_source
			give.activator_die = activator_die
			give.die_value = activator_die.value
			var targeted: Enemy = null
			if Globals.targeting_computer:
				targeted = Globals.targeting_computer.target_for(activator_die)
			if is_instance_valid(targeted):
				give.targets = [targeted]
			engine.inject_event(give)
		else:
			Globals.player.dice_manager.add(activator_die, true, false)

	# This stands in for the activation the lockout canceled, so the turn
	# still gets its end-of-activation check: a locked tile can be the last
	# one the hand was waiting on.
	engine.inject_event(TileActivationCompleteEvent.new())
