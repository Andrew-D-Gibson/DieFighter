class_name TargetRandomLockableTileHandler
extends EffectHandler

## Like TargetRandomTileHandler, but only among tiles a lockout could take hold
## on, so a random lock never lands on a tile that's already locked (or immune)
## while an open one is free. With none free it targets nothing and fizzles.
func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var lockable: Array[Tile] = Globals.tile_grid.tile_locations.values().filter(
		func(tile: Tile) -> bool: return tile.accepts_lockout())

	if lockable.is_empty():
		context.targets = []
		return

	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, lockable) as Node]
