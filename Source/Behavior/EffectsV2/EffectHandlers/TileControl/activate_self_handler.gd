class_name ActivateSelfHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	var event := ActivateSelfEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	engine.queue_event(event)
