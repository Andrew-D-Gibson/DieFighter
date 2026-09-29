class_name ZoomPunchHandler
extends EffectHandler

## data.multiplier: peak zoom relative to the camera's resting zoom
## (1.05 = 5% closer). Leans toward the first target when there is one.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.multiplier <= 1.0:
		return

	var event := ZoomPunchEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.peak_zoom = data.multiplier
	engine.inject_event(event)
