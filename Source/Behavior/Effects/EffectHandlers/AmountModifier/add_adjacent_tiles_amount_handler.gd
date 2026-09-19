class_name AddAdjacentTilesAmountHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	if context.effect_source is not Tile:
		return

	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(context.effect_source as Tile)

	if not Globals.tile_grid.is_grid_pos_valid(source_tile_pos):
		return

	var adjacent_count := 0

	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var check_pos: Vector2i = source_tile_pos + Vector2i(x, y)
			if Globals.tile_grid.is_grid_pos_valid(check_pos) and Globals.tile_grid.tile_locations.has(check_pos):
				adjacent_count += 1

	context.running_amount += adjacent_count
