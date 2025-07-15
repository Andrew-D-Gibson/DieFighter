class_name AddTileDataToAmountEffect
extends Effect

@export var tile_data_key: String

func play(effect_variables: EffectVariables) -> void:
	if not tile_data_key:
		printerr("AddTileDataToAmountEffect being called with a null string tile_data_key!")
		return
		
	if effect_variables.effect_source is not Tile:
		printerr("AddTileDataToAmountEffect not being called on a tile!")
		return
		
	var tile: Tile = effect_variables.effect_source as Tile
	
	if not tile.effect_data.has(tile_data_key):
		tile.effect_data[tile_data_key] = 0
		
	effect_variables.add_amount_modifier(func(amount: int) -> int:
		return amount + tile.effect_data[tile_data_key]
	)
