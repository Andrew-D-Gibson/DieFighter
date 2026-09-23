class_name ShakeDiceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return

	var event := ShakeDiceEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
