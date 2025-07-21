class_name PullAllTilesTowardColumnEffect
extends Effect

## A column of -1 inherits the column of the activating tile
@export_range(-1,4) var target_column: int

func play(effect_variables: EffectVariables) -> void:
	var column: int = target_column
	
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
	
	# Move every tile in the proper direction
	for direction in [-1, 1]:
		var tiles_to_move = []
		for tile_location in Globals.tile_grid.tile_locations.keys():
			if sign(column - tile_location.x) == direction:
				tiles_to_move.append(tile_location)

		# Sort appropriately
		if direction == 1:
			tiles_to_move.sort_custom(func(a, b): return a.x > b.x)
		else:
			tiles_to_move.sort_custom(func(a, b): return a.x < b.x)
			
		# Move tiles
		for tile_location in tiles_to_move:
			# Check if the tile is still at this position
			if not Globals.tile_grid.tile_locations.has(tile_location):
				continue
				
			var end_location = tile_location + Vector2i(direction, 0)
			
			# Only move if the destination is open
			if Globals.tile_grid.is_grid_pos_open(end_location):
				var tile = Globals.tile_grid.tile_locations[tile_location]
				Globals.tile_grid.move_tile(tile, end_location)
				
				Events.tile_pushed.emit(tile)
