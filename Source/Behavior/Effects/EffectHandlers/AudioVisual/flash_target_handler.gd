class_name FlashTargetHandler
extends EffectHandler

## data.color: the flash color. White reads as a clean impact frame.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event := FlashTargetEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.color = data.color
	engine.inject_event(event)
