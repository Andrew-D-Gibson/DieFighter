class_name AnimateDieToTileHandler
extends EffectHandler

## Tweens the activator die to a tile position offset from the effect source.
## data.grid_offset: tile offset from the source tile (e.g. Vector2i(1, 0) = one tile to the right).
## A value of Vector2i(0, 0) animates the die back to its own tile.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return
	if not is_instance_valid(context.effect_source):
		return
	if context.effect_source is not Tile:
		return

	var source_pos: Vector2i = Globals.tile_grid.find_tile_pos(context.effect_source as Tile)
	if not Globals.tile_grid.is_grid_pos_valid(source_pos):
		push_error("AnimateDieToTileHandler: could not find source tile position.")
		return

	var target_pos: Vector2i = source_pos + data.grid_offset
	if not Globals.tile_grid.is_grid_pos_valid(target_pos):
		push_error("AnimateDieToTileHandler: target grid position is invalid.")
		return

	var event := AnimateDieToTileEvent.new()
	event.actor             = context.actor
	event.effect_source     = context.effect_source
	event.activator_die     = context.activator_die
	event.target_global_pos = Globals.tile_grid.grid_to_global_pos(target_pos)
	engine.queue_event(event)
