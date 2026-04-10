class_name AddAmplifierStatusEvent
extends EffectEvent

var _amplifier_status_scene: PackedScene = preload("uid://mtf5i14nphib")


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(effect_source):
		return
	if effect_source is not Tile:
		return
	if not Globals.tile_grid.tile_locations.values().has(effect_source):
		return

	var grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(effect_source)
	var status: AmplifierTileStatus = _amplifier_status_scene.instantiate()
	status.amplifier_tile = effect_source

	var amplify_amount: int = amount
	status.amplifier_amount_modifier = func(a: int) -> int:
		return a + amplify_amount

	Events.add_status_to_grid_pos.emit(grid_pos, status)
