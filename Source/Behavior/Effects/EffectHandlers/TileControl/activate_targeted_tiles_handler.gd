class_name ActivateTargetedTilesHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event := ActivateTargetedTilesEvent.new()
	_stamp(event, context)
	event.targets       = context.targets.duplicate()
	engine.inject_event(event)
