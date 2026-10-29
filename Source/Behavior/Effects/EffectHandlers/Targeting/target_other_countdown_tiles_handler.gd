class_name TargetOtherCountdownTilesHandler
extends EffectHandler
## Targets every countdown tile on the grid except the source, for a tile
## that works the others' counts (Fuse Cutter). Nothing when there are none:
## the OTHER_COUNTDOWN_ON_GRID check refuses the die before it gets here.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var targets: Array[Node] = []
	for tile: Tile in TileCountdown.others_on_grid(context.effect_source as Tile):
		targets.append(tile)
	context.targets = targets
