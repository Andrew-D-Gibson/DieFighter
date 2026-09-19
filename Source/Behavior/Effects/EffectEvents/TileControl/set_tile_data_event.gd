class_name SetTileDataEvent
extends EffectEvent

var data_key: String = ""


func resolve(_engine: ScenarioEngine) -> void:
	if data_key.is_empty():
		push_error("SetTileDataEvent: data_key is empty.")
		return
	if not is_instance_valid(effect_source) or effect_source is not Tile:
		push_error("SetTileDataEvent: effect_source is not a Tile.")
		return

	(effect_source as Tile).effect_data[data_key] = amount
