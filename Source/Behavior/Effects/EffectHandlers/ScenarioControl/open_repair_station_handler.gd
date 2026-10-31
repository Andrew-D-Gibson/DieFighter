class_name OpenRepairStationHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: OpenRepairStationEvent = OpenRepairStationEvent.new()
	event.keeper = context.actor as Enemy
	engine.inject_event(event)
