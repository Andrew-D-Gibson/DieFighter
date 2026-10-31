class_name OpenRepairStationEvent
extends EffectEvent


## The dock ship opening the station, whose arrival effect this is.
var keeper: Enemy = null


func resolve(_engine: ScenarioEngine) -> void:
	Events.open_repair_station.emit(keeper if is_instance_valid(keeper) else null)
