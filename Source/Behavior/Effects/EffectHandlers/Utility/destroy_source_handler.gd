class_name DestroySourceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	var event := DestroySourceEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
