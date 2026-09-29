class_name VignettePulseHandler
extends EffectHandler

## data.color: the vignette color.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := VignettePulseEvent.new()
	_stamp(event, context)
	event.color = data.color
	engine.inject_event(event)
