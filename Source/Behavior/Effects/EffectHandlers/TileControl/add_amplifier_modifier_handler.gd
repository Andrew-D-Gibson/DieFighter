class_name AddAmplifierModifierHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: AddAmplifierModifierEvent = AddAmplifierModifierEvent.new()
	_stamp(event, context)
	event.targets       = context.targets.duplicate()
	event.amount        = context.running_amount
	engine.inject_event(event)
