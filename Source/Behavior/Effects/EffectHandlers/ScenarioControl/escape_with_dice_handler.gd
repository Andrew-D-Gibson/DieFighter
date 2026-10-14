class_name EscapeWithDiceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor):
		return

	var event := EscapeWithDiceEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
