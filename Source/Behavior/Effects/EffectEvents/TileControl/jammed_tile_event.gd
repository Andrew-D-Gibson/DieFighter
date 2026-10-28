class_name JammedTileEvent
extends EffectEvent
## Stands in for a tile activation a Jammed player canceled: the tile does
## nothing, and the die goes where the tile's chain would have sent it in the
## end, to the ship it was aimed at. The use isn't spent; the die is the cost.
##
## Mirrors the enemy side, where a jammed ship's die does nothing and goes
## back across to the player.

var tile: Tile


func resolve(engine: ScenarioEngine) -> void:
	if is_instance_valid(tile):
		tile.dice_queue.remove(activator_die)
		tile.play_refusal_feedback()
		tile.shakeable.large_shake()

	if is_instance_valid(activator_die):
		var give: GiveDieToTargetEvent = GiveDieToTargetEvent.new()
		give.actor = actor
		give.effect_source = tile
		give.activator_die = activator_die
		var target: Enemy = Globals.targeting_computer.target_for(activator_die) \
			if Globals.targeting_computer else null
		if target:
			give.targets = [target]
		engine.inject_event(give)

	# This stands in for the activation it canceled, so the turn still gets
	# its end-of-activation check, as a lockout's does.
	engine.inject_event(TileActivationCompleteEvent.new())
