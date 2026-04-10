class_name MoveTileWithOffsetHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	var event := MoveTileWithOffsetEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.offset        = data.grid_offset
	engine.queue_event(event)
