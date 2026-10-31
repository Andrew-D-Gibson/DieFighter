class_name OpenShopEvent
extends EffectEvent


## The ship opening the shop, whose arrival effect this is.
var keeper: Enemy = null


func resolve(_engine: ScenarioEngine) -> void:
	Events.open_shop.emit(keeper if is_instance_valid(keeper) else null)
