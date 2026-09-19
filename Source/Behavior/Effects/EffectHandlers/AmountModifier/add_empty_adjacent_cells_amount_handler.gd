class_name AddEmptyAdjacentCellsAmountHandler
extends EffectHandler
## Adds the number of EMPTY cells around the source tile to running_amount.
##
## The exact inverse of ADD_ADJACENT_TILES. Every adjacency effect in the game
## so far rewards packing the grid; this one rewards clearance, which makes a
## sparse board a build rather than an unfinished one. Cells outside the grid
## don't count — only real empty space inside it.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	if context.effect_source is not Tile:
		return

	var source_pos: Vector2i = Globals.tile_grid.find_tile_pos(context.effect_source as Tile)
	if not Globals.tile_grid.is_grid_pos_valid(source_pos):
		return

	var empty_count: int = 0
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var check_pos: Vector2i = source_pos + Vector2i(x, y)
			if not Globals.tile_grid.is_grid_pos_valid(check_pos):
				continue
			if Globals.tile_grid.is_grid_pos_open(check_pos):
				empty_count += 1

	context.running_amount += empty_count
