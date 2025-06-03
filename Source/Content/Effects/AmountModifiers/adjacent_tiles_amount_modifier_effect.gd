class_name AdjacentTilesAmountModifierEffect
extends Effect

@export var base_amount: int = 1
@export var amount_per_adjacent: int = 1

func play(effect_variables: EffectVariables) -> void:
	# Calculate number of adjacent occupied tiles
	var adjacent_count = 0
	# Get the tile's position using the helper function
	var pos: Vector2i = Globals.tile_grid.find_tile_pos(effect_variables.effect_source as Tile)

	# Check if the tile was found (it should be if the effect is playing)
	if not Globals.tile_grid.is_grid_pos_valid(pos):
		printerr("AdjacentTilesAmountModifierEffect couldn't find source tile position!")
		return

	# Check all 8 adjacent positions
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var check_pos: Vector2i = pos + Vector2i(x, y)
			# Check if the adjacent position is valid and occupied
			if Globals.tile_grid.is_grid_pos_valid(check_pos)\
				and Globals.tile_grid.tile_locations.has(check_pos):
				adjacent_count += 1

	# Add modifier that adds base damage plus damage per adjacent tile
	effect_variables.add_amount_modifier(func(amount: int) -> int:
		return base_amount + (adjacent_count * amount_per_adjacent)
	) 
