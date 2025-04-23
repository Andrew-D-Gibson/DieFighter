class_name OpenShopEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	Events.open_shop.emit()
