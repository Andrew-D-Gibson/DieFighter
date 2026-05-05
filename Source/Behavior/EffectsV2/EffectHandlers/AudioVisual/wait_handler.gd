class_name WaitHandler
extends EffectHandler

## data.amount: milliseconds to wait.

func apply(data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	if data.amount <= 0:
		return

	var event := WaitEvent.new()
	event.amount = data.amount
	engine.inject_event(event)
