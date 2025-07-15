class_name ActivateSelfEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if effect_variables.effect_source is not Tile:
		printerr("ActivateSelfEffect called on not a tile!")
		return
			
	effect_variables.effect_source.try_to_activate()
