class_name AttackTweenHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	if not is_instance_valid(context.activator_die):
		return

	var event := AttackTweenEvent.new()
	_stamp(event, context)
	event.targets       = context.targets.duplicate()
	engine.inject_event(event)
