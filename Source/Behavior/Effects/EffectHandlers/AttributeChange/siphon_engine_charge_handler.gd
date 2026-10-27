class_name SiphonEngineChargeHandler
extends EffectHandler

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: SiphonEngineChargeEvent = SiphonEngineChargeEvent.new()
	event.amount = context.running_amount
	event.color = data.color
	_stamp(event, context)
	engine.inject_event(event)
