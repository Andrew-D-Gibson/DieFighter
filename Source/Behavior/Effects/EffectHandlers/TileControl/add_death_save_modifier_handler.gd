class_name AddDeathSaveModifierHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: AddDeathSaveModifierEvent = AddDeathSaveModifierEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
