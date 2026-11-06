class_name HurryNextWaveHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: HurryNextWaveEvent = HurryNextWaveEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
