class_name GiveDieAwayHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor):
		return

	var event := GiveDieAwayEvent.new()
	event.actor = context.actor
	engine.inject_event(event)
