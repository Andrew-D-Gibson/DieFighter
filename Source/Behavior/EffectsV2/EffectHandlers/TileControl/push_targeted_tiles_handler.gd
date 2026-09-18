class_name PushTargetedTilesHandler
extends EffectHandler
## Shoves every tile in context.targets one cell.
##
## PUSH_TILE_IN_DIRECTION pushes the chain's own effect_source, which only works
## for a tile pushing itself. Enemies need to push a tile they've *targeted*, so
## this reads context.targets instead.
##
## data.grid_offset is the push direction. Vector2i.ZERO means "pick a cardinal
## direction at random", rolled once per target so a multi-target quake scatters
## the grid rather than sliding it.

const _CARDINALS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	for target: Node in context.targets:
		if not is_instance_valid(target) or target is not Tile:
			continue

		var direction: Vector2i = data.grid_offset
		if direction == Vector2i.ZERO:
			direction = RNGManager.pick_random(RNGManager.Bucket.TARGETING, _CARDINALS)

		var event := PushTileInDirectionEvent.new()
		event.actor         = context.actor
		event.effect_source = target
		event.direction     = direction
		engine.inject_event(event)
