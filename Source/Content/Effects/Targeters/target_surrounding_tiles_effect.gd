class_name TargetSurroundingTilesEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source:
		printerr("TargetSurroundingTilesEffect doesn't have an effect_source!")
		return
		
	# Get the tile's position using the helper function
	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(effect_variables.effect_source as Tile)

	# Check if the tile was found (it should be if the effect is playing)
	if not Globals.tile_grid.is_grid_pos_valid(source_tile_pos):
		printerr("TargetSurroundingTilesEffect couldn't find source tile position!")
		return

	effect_variables.targets = []
	
	# Check all 8 adjacent positions
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var check_pos: Vector2i = source_tile_pos + Vector2i(x, y)
			# Check if the adjacent position is valid and occupied
			if Globals.tile_grid.is_grid_pos_valid(check_pos)\
				and Globals.tile_grid.tile_locations.has(check_pos):
					effect_variables.targets.append(
						Globals.tile_grid.tile_locations[check_pos]
					)
	
