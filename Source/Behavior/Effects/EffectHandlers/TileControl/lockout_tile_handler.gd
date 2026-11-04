class_name LockoutTileHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: AddLockoutModifierEvent = AddLockoutModifierEvent.new()
	_stamp(event, context)
	event.targets  = context.targets.duplicate()
	event.is_asteroid = data.string_param == "asteroid"
	engine.inject_event(event)
