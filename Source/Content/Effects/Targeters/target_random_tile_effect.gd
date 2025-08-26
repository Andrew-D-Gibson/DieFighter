class_name TargetRandomTileEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	var all_tiles: Array[Tile] = Globals.tile_grid.tile_locations.values()
	
	effect_variables.targets = [all_tiles.pick_random()]
