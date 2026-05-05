class_name SetTileDataHandler
extends EffectHandler

## data.string_param: the dictionary key to set on the tile.
## data.amount: the integer value to store.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.string_param.is_empty():
		push_error("SetTileDataHandler: string_param (data key) is not set.")
		return

	var event := SetTileDataEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.data_key      = data.string_param
	event.amount        = data.amount
	engine.inject_event(event)
