class_name CountDownHandler
extends EffectHandler
## Counts down the countdown tiles in context.targets by running_amount
## (TARGET_EFFECT_SOURCE for the tile's own count). Targets that don't count
## down are passed over.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty() or context.running_amount <= 0:
		return

	var event := CountDownEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.amount = context.running_amount
	engine.inject_event(event)
