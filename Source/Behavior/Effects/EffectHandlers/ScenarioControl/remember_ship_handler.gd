class_name RememberShipHandler
extends EffectHandler
## The actor ship is remembered; string_param is the kind ("ally", "debt").


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not context.actor is Enemy:
		return
	var event: RememberShipEvent = RememberShipEvent.new()
	_stamp(event, context)
	event.kind = data.string_param if not data.string_param.is_empty() else FateLedger.KIND_ALLY
	engine.inject_event(event)
