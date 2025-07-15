class_name SetTileDataEffect
extends Effect

@export var tile_data_key: String
@export var value: int = 0

func play(effect_variables: EffectVariables) -> void:
	if not tile_data_key:
		printerr("SetTileDataEffect being called with a null string tile_data_key!")
		return
		
	if effect_variables.effect_source is not Tile:
		printerr("SetTileDataEffect not being called on a tile!")
		return
		
	var tile: Tile = effect_variables.effect_source as Tile
	
	tile.effect_data[tile_data_key] = value
