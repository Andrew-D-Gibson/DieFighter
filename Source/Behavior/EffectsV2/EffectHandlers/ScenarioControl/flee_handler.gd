class_name FleeHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor):
		return

	var event := FleeEvent.new()
	event.actor = context.actor
	engine.queue_event(event)
