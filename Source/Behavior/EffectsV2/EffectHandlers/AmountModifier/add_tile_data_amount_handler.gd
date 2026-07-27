class_name AddTileDataAmountHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	if context.effect_source is not Tile:
		return

	var tile: Tile = context.effect_source as Tile
	var tile_value: int = tile.effect_data.get(data.string_param, 0)
	context.running_amount += tile_value
