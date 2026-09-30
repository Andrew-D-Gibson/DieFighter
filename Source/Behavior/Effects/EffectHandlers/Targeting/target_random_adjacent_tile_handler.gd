class_name TargetRandomAdjacentTileHandler
extends EffectHandler
## Targets one random tile directly above, below, left or right of the source
## tile — the four directions a die can be Fed.
##
## Only occupied cells are candidates, so a router with any neighbour at all
## always sends the die somewhere real. With none, targets come back empty and
## a following PASS_DIE_TO_TILE hands the die to the enemy.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.targets = []

	if not is_instance_valid(context.effect_source) or context.effect_source is not Tile:
		printerr("TargetRandomAdjacentTileHandler's effect_source is not a Tile!")
		return

	var grid: TileGrid = Globals.tile_grid
	var source_pos: Vector2i = grid.find_tile_pos(context.effect_source as Tile)
	if not grid.is_grid_pos_valid(source_pos):
		printerr("TargetRandomAdjacentTileHandler couldn't find source tile position!")
		return

	var neighbours: Array[Tile] = []
	for direction: Vector2i in TileGrid.CARDINAL_DIRECTIONS:
		var pos: Vector2i = source_pos + direction
		if grid.tile_locations.has(pos):
			neighbours.append(grid.tile_locations[pos])

	if neighbours.is_empty():
		return

	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, neighbours) as Node]
