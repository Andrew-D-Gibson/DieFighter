class_name RerollTargetsDiceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var event := ChangeHeldDiceEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.change = ChangeHeldDiceEvent.Change.REROLL
	engine.inject_event(event)
