class_name DestroySourceHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	var event := DestroySourceEvent.new()
	event.effect_source = context.effect_source
	engine.queue_event(event)
