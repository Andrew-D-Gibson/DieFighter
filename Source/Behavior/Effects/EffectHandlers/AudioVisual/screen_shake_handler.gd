class_name ScreenShakeHandler
extends EffectHandler

## data.amount: 1 small, 2 large, 3 large with a glitch.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.amount <= 0:
		return

	var event := ScreenShakeEvent.new()
	_stamp(event, context)
	event.amount = data.amount
	engine.inject_event(event)
