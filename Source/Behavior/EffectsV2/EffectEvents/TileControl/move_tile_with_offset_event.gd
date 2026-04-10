class_name MoveTileWithOffsetEvent
extends EffectEvent

var offset: Vector2i = Vector2i.ZERO


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(effect_source):
		return
	if effect_source is not Tile:
		return

	var source_pos: Vector2i = Globals.tile_grid.find_tile_pos(effect_source as Tile)
	var new_pos: Vector2i = source_pos + offset

	if not Globals.tile_grid.is_grid_pos_valid(new_pos):
		push_error("MoveTileWithOffsetEvent: target position is invalid.")
		return

	Globals.tile_grid.move_tile(effect_source as Tile, new_pos)
