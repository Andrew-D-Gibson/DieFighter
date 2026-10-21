class_name CloseRepairStationEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	Events.close_repair_station.emit()
