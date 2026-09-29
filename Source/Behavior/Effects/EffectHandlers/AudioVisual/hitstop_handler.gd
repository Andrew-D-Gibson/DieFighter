class_name HitstopHandler
extends EffectHandler

## data.amount: milliseconds to freeze for.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.amount <= 0:
		return

	var event := HitstopEvent.new()
	_stamp(event, context)
	event.amount = data.amount
	engine.inject_event(event)
