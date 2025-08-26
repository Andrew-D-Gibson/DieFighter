class_name LockoutTargetTileEffect
extends Effect

var lockout_status_scene: PackedScene = preload("uid://be4hfdy3e3xfw")


func play(effect_variables: EffectVariables) -> void:
	if len(effect_variables.targets) > 0 and \
	effect_variables.targets[0] and\
	effect_variables.targets[0] is Tile and\
	Globals.tile_grid.tile_locations.values().has(effect_variables.targets[0]):
		var grid_pos: Vector2i = \
			Globals.tile_grid.tile_locations.find_key(
				effect_variables.targets[0]
			)
			
		var lockout_status: LockoutStatus = lockout_status_scene.instantiate()

		Events.add_status_to_grid_pos.emit(grid_pos, lockout_status)
