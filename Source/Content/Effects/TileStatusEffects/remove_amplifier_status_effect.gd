class_name RemoveAmplifierStatusEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if effect_variables.effect_source and\
	effect_variables.effect_source is Tile and\
	Globals.tile_grid.tile_locations.values().has(effect_variables.effect_source):
		var grid_pos: Vector2i = \
			Globals.tile_grid.tile_locations.find_key(
				effect_variables.effect_source
			)
			
		for status_effect: GridStatusEffect in Globals.tile_grid.grid_status_effects:
			if status_effect is AmplifierTileStatus and\
			Globals.tile_grid.grid_status_effects[status_effect] == grid_pos:
				status_effect.queue_free()
				return
