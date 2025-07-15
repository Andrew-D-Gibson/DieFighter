class_name ActivateTargetedTilesEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if len(effect_variables.targets) <= 0:
		printerr("ActivateTargetedTileEffect has no targets!")
		return
		
	for target in effect_variables.targets:
		if target is not Tile:
			continue
			
		target.try_to_activate()
