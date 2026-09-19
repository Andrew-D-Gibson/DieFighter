class_name TargetTileWithOffsetHandler
extends EffectHandler

func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		printerr("TargetTileWithOffsetHandler doesn't have an effect_source!")
		context.targets = []
		return

	if context.effect_source is not Tile:
		printerr("TargetTileWithOffsetHandler's effect_source is not a Tile!")
		context.targets = []
		return

	# Get the tile's position using the helper function
	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(
		context.effect_source as Tile
	)

	# Check if the tile was found (it should be if the effect is playing)
	if not Globals.tile_grid.is_grid_pos_valid(source_tile_pos):
		printerr("TargetTileWithOffsetHandler couldn't find source tile position!")
		context.targets = []
		return

	context.targets = []
	
	# Check for a tile in the offset position
	var check_pos: Vector2i = source_tile_pos + data.grid_offset
	if Globals.tile_grid.is_grid_pos_valid(check_pos)\
		and Globals.tile_grid.tile_locations.has(check_pos):
			context.targets.append(
				Globals.tile_grid.tile_locations[check_pos]
			)
