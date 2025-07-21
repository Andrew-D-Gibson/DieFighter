class_name PullAllTilesTowardColumnEffect
extends Effect

## A column of -1 inherits the column of the activating tile
@export_range(-1,4) var column: int

func play(effect_variables: EffectVariables) -> void:
	# If the column is set to -1 inherit the column from the activating tile
	if column == -1:
		if not effect_variables.effect_source:
			printerr("PullAllTilesTowardColumnEffect is trying to inherit the column from a non-existent Tile!")
			return
			
		if effect_variables.effect_source is not Tile:
			printerr("PullAllTilesTowardColumnEffect is trying to inherit the column from something other than a Tile!")
			return
		
		var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(
			effect_variables.effect_source as Tile
		)
		
		column = source_tile_pos.x
	
	# Move every tile
	for tile_location in Globals.tile_grid.tile_locations.keys():
		if tile_location.x == column: 
			continue
			
		var direction: int = 1 if column > tile_location.x else -1
		
		var end_location: Vector2i = tile_location + Vector2i(direction, 0)
		
		## ADD CODE HERE
