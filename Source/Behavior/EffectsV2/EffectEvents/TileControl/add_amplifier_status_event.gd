class_name AddAmplifierStatusEvent
extends EffectEvent


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(effect_source):
		return
	if effect_source is not Tile:
		return

	var source_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(effect_source)
	if not Globals.tile_grid.is_grid_pos_valid(source_pos):
		return

	for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbor_pos: Vector2i = source_pos + offset
		if Globals.tile_grid.tile_locations.has(neighbor_pos):
			var neighbor_tile: Tile = Globals.tile_grid.tile_locations[neighbor_pos]
			engine.add_modifier(AmplifierModifier.new(neighbor_tile, amount))
