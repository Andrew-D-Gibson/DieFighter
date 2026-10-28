class_name TargetMirroredTileHandler
extends EffectHandler
## Targets the tile in the source tile's mirrored cell (TileGrid.mirror_of):
## same row, other side of the grid. Pair with PASS_DIE_TO_TILE for a relay
## that Feeds across, which on a twin-pod ship crosses the hull gap that no
## other Feed can.
##
## A centre-column tile mirrors onto itself and targets nothing, so its die
## goes to the targeted ship like any Feed with nowhere to go.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.targets = []
	var source: Tile = context.effect_source as Tile
	var grid: TileGrid = Globals.tile_grid
	if not is_instance_valid(source) or not is_instance_valid(grid):
		return

	var pos: Vector2i = grid.find_tile_pos(source)
	if not grid.is_grid_pos_valid(pos):
		return

	var mirrored: Vector2i = grid.mirror_of(pos)
	if mirrored != pos and grid.tile_locations.has(mirrored):
		context.targets.append(grid.tile_locations[mirrored])
