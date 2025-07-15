class_name PushTileInDirectionEffect
extends Effect

@export var direction: Vector2i

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source:
		printerr("PushTileInDirectionEffect doesn't have a source tile!")
		return
		
	if effect_variables.effect_source is not Tile:
		printerr("PushTileInDirectionEffect's source is not a tile!")
		return
	
	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(
		effect_variables.effect_source as Tile
	)

	# Only allow cardinal directions
	var allowed_directions = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	if not direction in allowed_directions:
		printerr("PushTileInDirectionEffect is trying to push a tile not in a cardinal direction!")
		return
		
	Globals.tile_grid.push_tile(effect_variables.effect_source as Tile, direction)
