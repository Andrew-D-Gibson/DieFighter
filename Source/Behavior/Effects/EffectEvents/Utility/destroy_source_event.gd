class_name DestroySourceEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(effect_source):
		return
	if effect_source is Tile and is_instance_valid(Globals.tile_grid):
		Globals.tile_grid.forget_tile(effect_source as Tile)
	effect_source.queue_free()
