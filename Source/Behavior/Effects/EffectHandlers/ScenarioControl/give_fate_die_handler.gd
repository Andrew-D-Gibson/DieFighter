class_name GiveFateDieHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: GiveFateDieEvent = GiveFateDieEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
