class_name CloseRepairStationHandler
extends EffectHandler


func apply(_data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	engine.inject_event(CloseRepairStationEvent.new())
