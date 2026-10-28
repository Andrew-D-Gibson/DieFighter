class_name FlipTargetsOnesAndSixesHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var event := ChangeHeldDiceEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.change = ChangeHeldDiceEvent.Change.FLIP_ONES_AND_SIXES
	event.color = data.color
	engine.inject_event(event)
