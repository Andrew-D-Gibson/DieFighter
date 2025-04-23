class_name CloseShopEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	Events.close_shop.emit()
