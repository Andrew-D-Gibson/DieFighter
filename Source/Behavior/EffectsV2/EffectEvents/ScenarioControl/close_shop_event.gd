class_name CloseShopEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	Events.close_shop.emit()
