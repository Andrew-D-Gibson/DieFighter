class_name PushTileInDirectionHandler
extends EffectHandler

## data.grid_offset encodes the push direction (e.g. Vector2i(1, 0) = push right).

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	var event := PushTileInDirectionEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.direction     = data.grid_offset
	engine.inject_event(event)
