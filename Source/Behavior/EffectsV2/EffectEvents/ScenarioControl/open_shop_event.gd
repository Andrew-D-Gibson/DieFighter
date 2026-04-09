class_name OpenShopEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	Events.open_shop.emit()
