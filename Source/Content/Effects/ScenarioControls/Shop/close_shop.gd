class_name CloseShopEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	print('Closing shop!')
	Events.close_shop.emit()
