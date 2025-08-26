class_name TargetEffectSourceEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source:
		printerr("TargetEffectSourceEffect does not have an effect source!")
		return
		
	effect_variables.targets = [effect_variables.effect_source]
