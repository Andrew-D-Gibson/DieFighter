class_name HoldDieForTurnsEvent
extends EffectEvent
## The source tile takes the activator die back into its queue and keeps it
## there until `amount` of the player's turns from now (HeldDieDelay).


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die) or activator_die.is_queued_for_deletion():
		return
	if not is_instance_valid(effect_source) or effect_source is not Tile:
		return

	var tile: Tile = effect_source as Tile
	tile.dice_queue.add(activator_die, true, false)
	activator_die.draggable.state = Draggable.DragState.DEFAULT
	engine.add_modifier(HeldDieDelay.new(tile, activator_die, amount))


## A number of turns, not an output.
func is_amplifiable() -> bool:
	return false
