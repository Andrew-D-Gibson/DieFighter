class_name TileActivationEvent
extends EffectEvent

var tile: Tile

func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(tile):
		return

	# Activation criteria check (uses remaining, ActivationResource checks)
	if not tile.clears_activation_criteria(activator_die):
		# Return the die to the player's hand and get it out of the visual queue
		if is_instance_valid(activator_die):
			Globals.player.dice_manager.add(activator_die, true, false)
		tile.dice_queue.remove(activator_die)
		return

	# Decrement uses now that we're committed to activating
	if tile.uses_remaining != -1:
		tile.uses_remaining -= 1

	# Remove die from the visual stacking queue — it's about to fly to tile center
	tile.dice_queue.remove(activator_die)

	# Tween the die to the tile center (identical to old Tile.activate() tween)
	if activator_die:
		activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		var tween_time: float = 0.2 / Globals.animation_speed
		var tween: Tween = tile.create_tween().set_parallel(true)
		tween.tween_property(
			activator_die,
			'global_position',
			tile.global_position + Vector2(0, 6),
			tween_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(
			activator_die,
			'scale',
			Vector2(0.75, 0.75),
			tween_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished

	tile.shakeable.large_shake()

	# Build the EffectContext for this activation
	var context: EffectContext = EffectContext.new()
	context.actor = Globals.player
	context.effect_source = tile
	context.activator_die = activator_die

	# Play the v2 effect chain — this enqueues more events; the engine's while-loop
	# picks them up automatically because they're appended to the same event_queue.
	if tile.tile_resource.effect_chain_v2:
		await tile.tile_resource.effect_chain_v2.play(context, engine)

	Events.tile_activation_complete.emit()
