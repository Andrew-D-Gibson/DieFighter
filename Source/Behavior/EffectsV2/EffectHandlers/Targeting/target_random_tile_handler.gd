class_name TargetRandomTileHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var all_tiles: Array[Tile] = Globals.tile_grid.tile_locations.values()
	
	if all_tiles.is_empty():
		context.targets = []
		return
		
	context.targets = [all_tiles.pick_random() as Node]
