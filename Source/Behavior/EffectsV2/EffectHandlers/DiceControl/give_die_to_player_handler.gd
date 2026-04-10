class_name GiveDieToPlayerHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return

	var event := GiveDieToPlayerEvent.new()
	event.activator_die = context.activator_die
	event.actor         = context.actor
	engine.queue_event(event)
