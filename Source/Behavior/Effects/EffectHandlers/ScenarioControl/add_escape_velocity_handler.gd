class_name AddEscapeVelocityHandler
extends EffectHandler
## Reads the escape charge from context.running_amount.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: AddEscapeVelocityEvent = AddEscapeVelocityEvent.new()
	_stamp(event, context)
	event.amount = context.running_amount
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
