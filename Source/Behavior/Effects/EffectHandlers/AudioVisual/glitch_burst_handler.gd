class_name GlitchBurstHandler
extends EffectHandler

## data.amount: milliseconds the glitch overlay stays on.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.amount <= 0:
		return

	var event := GlitchBurstEvent.new()
	_stamp(event, context)
	event.amount = data.amount
	engine.inject_event(event)
