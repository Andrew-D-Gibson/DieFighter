class_name MoveDieToTileEffect
extends Effect

@export var offset_from_source_tile: Vector2i = Vector2i(0,0)
var tween_time: float = 0.3

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		return
		
	if effect_variables.effect_source is not Tile:
		return
	
	var source_tile_pos: Vector2i = Globals.tile_grid.find_tile_pos(
		effect_variables.effect_source as Tile
	)

	if not Globals.tile_grid.is_grid_pos_valid(source_tile_pos):
		printerr("MoveDieToTileEffect couldn't find source tile position!")
		return
		
	var target_grid_pos: Vector2i = source_tile_pos + offset_from_source_tile
	if not Globals.tile_grid.is_grid_pos_valid(target_grid_pos):
		printerr("MoveDieToTileEffect's target position is invalid!")
		return
		
	# With everything checked, now we tween the tile
	var die: Dice = effect_variables.activator_die
	var target_global_pos: Vector2 = Globals.tile_grid.grid_to_global_pos(target_grid_pos)
	
	var tween = effect_variables.actor.create_tween()
	tween.tween_property(die, 'global_position', target_global_pos, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
