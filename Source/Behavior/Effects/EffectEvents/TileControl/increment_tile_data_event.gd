class_name IncrementTileDataEvent
extends EffectEvent

var data_key: String = ""


func resolve(_engine: ScenarioEngine) -> void:
	if data_key.is_empty():
		push_error("IncrementTileDataEvent: data_key is empty.")
		return
	if not is_instance_valid(effect_source) or effect_source is not Tile:
		push_error("IncrementTileDataEvent: effect_source is not a Tile.")
		return

	var tile: Tile = effect_source as Tile
	if not tile.effect_data.has(data_key):
		tile.effect_data[data_key] = amount
	else:
		tile.effect_data[data_key] += amount
