class_name TransferStatusesHandler
extends EffectHandler
## Moves every status on the actor onto the first target.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: TransferStatusesEvent = TransferStatusesEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
