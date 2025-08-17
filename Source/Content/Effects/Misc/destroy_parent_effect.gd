class_name DestroyParentEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source or effect_variables.effect_source is not Tile:
		printerr("DestroyParentEffect does not have a Tile as the effect source!")
		return

	effect_variables.effect_source.get_parent().queue_free()
