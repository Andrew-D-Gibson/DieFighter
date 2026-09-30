class_name PassDieToTileEvent
extends EffectEvent
## Hands the activator die on to another tile and activates it with that die.
##
## ACTIVATE_TARGETED_TILES fires the next tile with no die, which means anything
## carrying REQUIRES_ACTIVATOR_DIE — most of the game's tiles — silently
## refuses. This passes the die itself, so a relay can actually feed a cannon.
##
## This is the "Feed" keyword: the die goes to the next tile only if that tile
## will actually take it, and to the targeted ship otherwise. A relay that
## isn't hooked into a working machine is therefore just an attack tile —
## being connected is how it earns more, never a way to get the die back.
##
## Chains built this way can loop. Every loop has to pass through a tile with
## limited uses, and runs dry when that tile refuses; ScenarioEngine's per-drain
## event ceiling is the backstop if a loop is ever authored without one.


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	# Relay runs off the end of the board, or into an empty cell.
	if targets.is_empty() or not is_instance_valid(targets[0]) or targets[0] is not Tile:
		_hand_die_off(engine)
		return

	# Checked here rather than left to TileActivationEvent, which hands a
	# refused die back to the player's hand — that would let an unlimited relay
	# pointed at a spent or picky tile fire for free, forever.
	var next_tile: Tile = targets[0] as Tile
	if not next_tile.clears_activation_criteria(activator_die):
		_hand_die_off(engine)
		return

	var event: TileActivationEvent = TileActivationEvent.new()
	event.tile = next_tile
	event.activator_die = activator_die
	event.die_value = activator_die.value
	engine.inject_event(event)


## Nowhere left to relay to. The die still has to go somewhere or it ends up
## floating in open space with no owner — TileActivationEvent already pulled it
## out of the source tile's queue. Give it to the targeted ship through the same
## event every other tile uses, so a relay's leftover die gets the same tractor
## beam, dead-target fallback and modifier hooks as a Dice Cannon's.
func _hand_die_off(engine: ScenarioEngine) -> void:
	var give: GiveDieToTargetEvent = GiveDieToTargetEvent.new()
	give.actor = actor
	give.effect_source = effect_source
	give.activator_die = activator_die
	give.die_value = activator_die.value

	var targeted: Enemy = null
	if Globals.targeting_computer:
		targeted = Globals.targeting_computer.targeted_enemy
	if is_instance_valid(targeted):
		give.targets = [targeted]

	engine.inject_event(give)
