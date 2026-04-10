class_name PullRowTilesToColumnHandler
extends EffectHandler

## data.grid_offset.x = target column (-1 to inherit from source tile's column).
## data.grid_offset.y = target row    (-1 to inherit from source tile's row).

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := PullRowTilesToColumnEvent.new()
	event.actor          = context.actor
	event.effect_source  = context.effect_source
	event.target_column  = data.grid_offset.x
	event.target_row     = data.grid_offset.y
	engine.queue_event(event)
