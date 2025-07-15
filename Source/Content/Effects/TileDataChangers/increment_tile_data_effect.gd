class_name IncrementTileDataEffect
extends Effect

@export var tile_data_key: String

func play(effect_variables: EffectVariables) -> void:
	if not tile_data_key:
		printerr("IncrementTileDataEffect being called with a null string tile_data_key!")
		return
		
	if effect_variables.effect_source is not Tile:
		printerr("IncrementTileDataEffect not being called on a tile!")
		return
		
	var tile: Tile = effect_variables.effect_source as Tile
	
	if not tile.effect_data.has(tile_data_key):
		tile.effect_data[tile_data_key] = 1
	else:
		tile.effect_data[tile_data_key] += 1
		
	print(tile_data_key, ' ', tile.effect_data[tile_data_key])
