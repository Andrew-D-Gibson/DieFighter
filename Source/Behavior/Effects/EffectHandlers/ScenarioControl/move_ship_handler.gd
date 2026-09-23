class_name MoveShipHandler
extends EffectHandler

## data.multiplier encodes the normalised path position (0.0–1.0).
## Reuses the multiplier field since it's the only float available in EffectData.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor):
		return

	var event := MoveShipEvent.new()
	_stamp(event, context)
	event.position_proportion = data.multiplier
	engine.inject_event(event)
