class_name SlowMoHandler
extends EffectHandler

## data.amount: milliseconds of real time to stay slowed.
## data.multiplier: the time scale to slow to (0.3 = 30% speed).

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.amount <= 0 or data.multiplier >= 1.0:
		return

	var event := SlowMoEvent.new()
	_stamp(event, context)
	event.amount = data.amount
	event.time_scale = data.multiplier
	engine.inject_event(event)
