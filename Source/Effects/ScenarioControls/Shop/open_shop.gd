extends Effect

func play(effect_variables: EffectVariables) -> void:
	print('Opening shop!')
	Events.open_shop.emit()
