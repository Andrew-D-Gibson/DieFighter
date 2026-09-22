class_name AddDeathSaveModifierHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: AddDeathSaveModifierEvent = AddDeathSaveModifierEvent.new()
	event.actor = context.actor
	event.effect_source = context.effect_source
	engine.inject_event(event)
