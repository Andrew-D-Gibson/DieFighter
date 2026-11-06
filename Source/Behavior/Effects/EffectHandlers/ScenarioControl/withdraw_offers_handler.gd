class_name WithdrawOffersHandler
extends EffectHandler


func apply(_data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	engine.inject_event(WithdrawOffersEvent.new())
