extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.targets = Array([effect_variables.source])
