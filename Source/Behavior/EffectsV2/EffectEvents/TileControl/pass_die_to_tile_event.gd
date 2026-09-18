class_name PassDieToTileEvent
extends EffectEvent
## Hands the activator die on to another tile and activates it with that die.
##
## ACTIVATE_TARGETED_TILES fires the next tile with no die, which means anything
## carrying REQUIRES_ACTIVATOR_DIE — most of the game's tiles — silently
## refuses. This passes the die itself, so a relay can actually feed a cannon.
##
## Chains built this way can loop (two relays pointing at each other), which
## ScenarioEngine's per-drain event ceiling exists to catch.


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	# Relay runs off the end of the board, or into an empty cell.
	if targets.is_empty() or not is_instance_valid(targets[0]) or targets[0] is not Tile:
		_hand_die_off()
		return

	var event: TileActivationEvent = TileActivationEvent.new()
	event.tile = targets[0] as Tile
	event.activator_die = activator_die
	event.die_value = activator_die.value
	engine.inject_event(event)


## Nowhere left to relay to. The die still has to go somewhere or it ends up
## floating in open space with no owner — TileActivationEvent already pulled it
## out of the source tile's queue. Hand it to the targeted ship, exactly as a
## normal tile would, and fall back to the player only if there's nobody there.
func _hand_die_off() -> void:
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	var targeted: Enemy = null
	if Globals.targeting_computer:
		targeted = Globals.targeting_computer.targeted_enemy

	if is_instance_valid(targeted) and targeted.health.health > 0:
		targeted.dice_manager.add(activator_die)
		return

	if is_instance_valid(Globals.player):
		Globals.player.dice_manager.add(activator_die)
