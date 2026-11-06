class_name EscapeWithDiceHandler
extends EffectHandler


## string_param "spent_only" carries only the die being spent; the rest the
## ship holds go home first (EscapeWithDiceEvent.spent_only).
func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor):
		return

	var event := EscapeWithDiceEvent.new()
	_stamp(event, context)
	event.spent_only = data.string_param == EscapeWithDiceEvent.SPENT_ONLY
	engine.inject_event(event)
