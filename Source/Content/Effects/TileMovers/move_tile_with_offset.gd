class_name MoveTileWithOffsetEffect
extends Effect

@export var offset: Vector2i = Vector2i(0,0)

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source:
		printerr("MoveTileWithOffsetEffect doesn't have a source tile!")
		return
		
	if effect_variables.effect_source is not Tile:
		printerr("MoveTileWithOffsetEffect's source is not a tile!")
		return
	
	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(
		effect_variables.effect_source as Tile
	)

	var new_pos: Vector2i = source_tile_pos + offset
	if not Globals.tile_grid.is_grid_pos_valid(new_pos):
		printerr("MoveTileWithOffsetEffect trying to move to an invalid position!")
		return
		
	Globals.tile_grid.move_tile(effect_variables.effect_source as Tile, new_pos)
