class_name DestroyTileEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source or effect_variables.effect_source is not Tile:
		printerr("DestroyTileEffect does not have a Tile as the effect source!")
		return
	
	effect_variables.effect_source.queue_free()
