class_name KeepDieWithTileEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(effect_source) or effect_source is not Tile:
		return

	(effect_source as Tile).dice_queue.add(activator_die, true, false)
	activator_die.draggable.state = Draggable.DragState.DEFAULT
