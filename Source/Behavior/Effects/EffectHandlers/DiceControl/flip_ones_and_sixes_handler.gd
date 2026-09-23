class_name FlipOnesAndSixesHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var flip_event := FlipOnesAndSixesEvent.new()
	_stamp(flip_event, context)
	
	engine.inject_event(flip_event)
