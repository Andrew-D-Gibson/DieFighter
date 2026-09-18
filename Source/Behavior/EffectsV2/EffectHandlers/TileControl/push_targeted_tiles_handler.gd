class_name PushTargetedTilesHandler
extends EffectHandler
## Shoves every tile in context.targets one cell.
##
## PUSH_TILE_IN_DIRECTION pushes the chain's own effect_source, which only works
## for a tile pushing itself. Enemies need to push a tile they've *targeted*, so
## this reads context.targets instead.
##
## data.grid_offset is the push direction. Vector2i.ZERO means "pick a cardinal
## direction at random", rolled per target so a multi-target quake scatters the
## grid rather than sliding it. A random shove prefers a direction the tile can
## actually move in — a telegraphed "your grid gets shoved" that silently does
## nothing because the tile was against a wall is a broken promise, not an
## interesting outcome.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	for target: Node in context.targets:
		if not is_instance_valid(target) or target is not Tile:
			continue

		var direction: Vector2i = data.grid_offset
		if direction == Vector2i.ZERO:
			direction = _pick_open_direction(target as Tile)

		var event := PushTileInDirectionEvent.new()
		event.actor         = context.actor
		event.effect_source = target
		event.direction     = direction
		engine.inject_event(event)


## A random cardinal direction this tile can actually be pushed in. Falls back to
## a plain random direction when the tile is completely boxed in.
func _pick_open_direction(tile: Tile) -> Vector2i:
	var candidates: Array[Vector2i] = TileGrid.CARDINAL_DIRECTIONS.duplicate()
	RNGManager.shuffle_array(RNGManager.Bucket.TARGETING, candidates)

	for direction: Vector2i in candidates:
		if Globals.tile_grid.can_push_tile(tile, direction):
			return direction

	return candidates[0]
