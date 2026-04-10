class_name FlipOnesAndSixesHandler
extends EffectHandler


func apply(_data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	engine.queue_event(FlipOnesAndSixesEvent.new())
