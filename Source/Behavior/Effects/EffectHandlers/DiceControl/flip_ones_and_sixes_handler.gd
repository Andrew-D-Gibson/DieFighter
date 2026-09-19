class_name FlipOnesAndSixesHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var flip_event := FlipOnesAndSixesEvent.new()
	flip_event.actor = context.actor
	
	engine.inject_event(flip_event)
