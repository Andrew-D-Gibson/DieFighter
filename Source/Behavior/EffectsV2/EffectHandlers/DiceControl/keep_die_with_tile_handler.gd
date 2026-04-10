class_name KeepDieWithTileHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return
	if not is_instance_valid(context.effect_source):
		return

	var event := KeepDieWithTileEvent.new()
	event.activator_die = context.activator_die
	event.effect_source = context.effect_source
	event.actor         = context.actor
	engine.queue_event(event)
