class_name FlipOnesAndSixesHandler
extends EffectHandler


func apply(_data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	engine.inject_event(FlipOnesAndSixesEvent.new())
