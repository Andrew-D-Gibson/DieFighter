class_name RerollAllDiceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := RerollAllDiceEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
