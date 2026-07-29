class_name WaitHandler
extends EffectHandler

## context.running_amount: milliseconds to wait.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.running_amount <= 0:
		return

	var event := WaitEvent.new()
	event.amount = context.running_amount
	engine.inject_event(event)
