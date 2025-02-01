extends Effect

func play(effect_variables: EffectVariables) -> void:
	await get_tree().create_timer(amount / float(1000)).timeout
