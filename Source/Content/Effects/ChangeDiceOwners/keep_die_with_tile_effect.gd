class_name KeepDieWithTileEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		printerr("KeepDieWithTileEffect doesn't have an activator die!")
		return
		
	if not effect_variables.effect_source or not effect_variables.effect_source is Tile:
		printerr("KeepDieWithTileEffect is not being triggered by a tile!")
		return
	
	effect_variables.effect_source.dice_queue.add(effect_variables.activator_die, true, false)
	effect_variables.activator_die.draggable.state = Draggable.DragState.DEFAULT
