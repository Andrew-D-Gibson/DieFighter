class_name IncrementTileDataHandler
extends EffectHandler

## data.string_param: the dictionary key to increment on the tile.
## context.running_amount: how much to increment by (defaults to 1 if 0).

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if data.string_param.is_empty():
		push_error("IncrementTileDataHandler: string_param (data key) is not set.")
		return

	var event := IncrementTileDataEvent.new()
	_stamp(event, context)
	event.data_key      = data.string_param
	event.amount        = context.running_amount if context.running_amount != 0 else 1
	engine.inject_event(event)
