class_name MultiplyStatusesHandler
extends EffectHandler
## Multiplies every status on the targets by the step's multiplier (Status
## Catalyst doubles). The statuses are read when the event resolves, so a
## status applied earlier in the same chain is multiplied too.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: MultiplyStatusesEvent = MultiplyStatusesEvent.new()
	_stamp(event, context)
	event.multiplier = data.multiplier
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
