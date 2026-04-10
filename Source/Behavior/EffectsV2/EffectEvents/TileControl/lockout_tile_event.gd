class_name LockoutTileEvent
extends EffectEvent

var _lockout_status_scene: PackedScene = preload("uid://be4hfdy3e3xfw")


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		if not Globals.tile_grid.tile_locations.values().has(target):
			continue

		var grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(target)
		var status: LockoutStatus = _lockout_status_scene.instantiate()
		Events.add_status_to_grid_pos.emit(grid_pos, status)
