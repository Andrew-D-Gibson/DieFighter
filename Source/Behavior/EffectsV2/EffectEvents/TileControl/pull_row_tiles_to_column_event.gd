class_name PullRowTilesToColumnEvent
extends EffectEvent

## Target column index. -1 inherits from the effect_source tile's column.
var target_column: int = -1

## Target row index. -1 inherits from the effect_source tile's row.
var target_row: int = -1


func resolve(_engine: ScenarioEngine) -> void:
	var column: int = target_column
	var row: int = target_row

	if column == -1 or row == -1:
		if not is_instance_valid(effect_source) or effect_source is not Tile:
			push_error("PullRowTilesToColumnEvent: need effect_source Tile to inherit column/row.")
			return
		var source_pos: Vector2i = Globals.tile_grid.find_tile_pos(effect_source as Tile)
		if column == -1:
			column = source_pos.x
		if row == -1:
			row = source_pos.y

	for direction: int in [1, -1]:
		var tiles_to_move: Array = []
		for tile_location: Vector2i in Globals.tile_grid.tile_locations.keys():
			if tile_location.y != row:
				continue
			if sign(column - tile_location.x) == direction:
				tiles_to_move.append(tile_location)

		if direction == 1:
			tiles_to_move.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x)
		else:
			tiles_to_move.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)

		for tile_location: Vector2i in tiles_to_move:
			if not Globals.tile_grid.tile_locations.has(tile_location):
				continue
			var end_location: Vector2i = tile_location + Vector2i(direction, 0)
			if Globals.tile_grid.is_grid_pos_open(end_location):
				var tile: Tile = Globals.tile_grid.tile_locations[tile_location]
				Globals.tile_grid.move_tile(tile, end_location)
				Events.tile_pushed.emit(tile)
