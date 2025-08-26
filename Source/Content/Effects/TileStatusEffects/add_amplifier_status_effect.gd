class_name AddAmplifierStatusEffect
extends Effect

var amplifier_tile_status_scene: PackedScene = preload("uid://mtf5i14nphib")


func play(effect_variables: EffectVariables) -> void:
	if effect_variables.effect_source and\
	effect_variables.effect_source is Tile and\
	Globals.tile_grid.tile_locations.values().has(effect_variables.effect_source):
		var grid_pos: Vector2i = \
			Globals.tile_grid.tile_locations.find_key(
				effect_variables.effect_source
			)
			
		var amplifier_tile_status: AmplifierTileStatus = amplifier_tile_status_scene.instantiate()
		amplifier_tile_status.amplifier_tile = effect_variables.effect_source
		Events.add_status_to_grid_pos.emit(grid_pos, amplifier_tile_status)
