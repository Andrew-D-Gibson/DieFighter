class_name TargetSurroundingTilesHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		printerr("TargetSurroundingTilesHandler doesn't have an effect_source!")
		context.targets = []
		return

	if context.effect_source is not Tile:
		printerr("TargetSurroundingTilesHandler's effect_source is not a Tile!")
		context.targets = []
		return

	# Get the tile's position using the helper function
	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(
		context.effect_source as Tile
	)

	# Check if the tile was found (it should be if the effect is playing)
	if not Globals.tile_grid.is_grid_pos_valid(source_tile_pos):
		printerr("TargetSurroundingTilesHandler couldn't find source tile position!")
		context.targets = []
		return

	context.targets = []
	
	# Check all 8 adjacent positions
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var check_pos: Vector2i = source_tile_pos + Vector2i(x, y)
			# Check if the adjacent position is valid and occupied
			if Globals.tile_grid.is_grid_pos_valid(check_pos)\
				and Globals.tile_grid.tile_locations.has(check_pos):
					context.targets.append(
						Globals.tile_grid.tile_locations[check_pos]
					)
