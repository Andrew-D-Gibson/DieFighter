class_name OpenRepairStationEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	Events.open_repair_station.emit()
