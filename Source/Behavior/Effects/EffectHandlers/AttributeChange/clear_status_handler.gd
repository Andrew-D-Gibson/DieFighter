class_name ClearStatusHandler
extends EffectHandler
## Removes the status named by string_param from every target.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: ClearStatusEvent = ClearStatusEvent.new()
	_stamp(event, context)
	event.status_id = StringName(data.string_param)
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
