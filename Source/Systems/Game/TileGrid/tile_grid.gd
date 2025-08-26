class_name TileGrid
extends Node2D

@export var grid_width: int = 5
@export var grid_height: int = 3
@export var grid_spacing: int = 24

var tile_scene: PackedScene = preload("uid://delq7kb5loqt2")
var tile_locations: Dictionary[Vector2i, Tile] = {}

var lockout_status_scene: PackedScene = preload("uid://be4hfdy3e3xfw")
var grid_status_effects: Dictionary[GridStatusEffect, Vector2i] = {}

@export var empty_cell_texture: Texture2D


func _ready() -> void:
	Globals.tile_grid = self
	
	Events.load_game_save.connect(_load_game_save)
	Events.start_combat.connect(Events.show_systems.emit)
	Events.combat_finished.connect(clear_status_effects)
	Events.add_status_to_grid_pos.connect(_add_status_to_grid_pos)
	
	_setup_grid_graphics()
	
	
func _load_game_save(game_save: GameSaveResource) -> void:
	_setup_tiles(game_save.tile_locations)
	
	
func _setup_grid_graphics() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			# Add an empty cell sprite
			var empty_cell = Sprite2D.new()
			empty_cell.texture = empty_cell_texture
			empty_cell.z_index = -1
			empty_cell.position = Vector2(
				(x + 0.5) * grid_spacing,		# The added 0.5 is to offset the tiles 
				(y + 0.5) * grid_spacing		# to their top left, rather than their center 
			)
			
			add_child(empty_cell)
	
	
func _setup_tiles(_tile_locations: Dictionary[Vector2i, TileResource]) -> void:
	# Clear existing tiles before setting up new ones, if any
	for pos in tile_locations.keys():
		if is_instance_valid(tile_locations[pos]):
			tile_locations[pos].queue_free()
	tile_locations.clear()

	for tile_grid_pos in _tile_locations.keys():
		var tile_resource = _tile_locations[tile_grid_pos]

		# Create a tile scene and give it the proper resource
		var tile = tile_scene.instantiate()
		tile.tile_resource = tile_resource
		add_child(tile)

		# Find the tile's world position (already have grid pos)
		var tile_world_pos: Vector2 = grid_to_global_pos(tile_grid_pos)

		# Set up the tile's initial position
		tile.global_position = tile_world_pos

		# Set the tile within the grid representation
		_assign_tile_to_grid_pos(tile as Tile, tile_grid_pos)

		# Disable the first sound effect of the tile being dropped
		tile.draggable.emit_reached_new_home = false

		# Connect the tile's drag ended signal to the function to snap it to the grid
		tile.draggable.drag_ended.connect(_drop_tile_on_grid_pos)


func _assign_tile_to_grid_pos(tile: Tile, grid_pos: Vector2i) -> void:
	# Find the tile's current position, if it exists
	var old_pos: Vector2i = find_tile_pos(tile)

	# If the tile was already in the grid, remove its old entry
	if is_grid_pos_valid(old_pos):
		tile_locations.erase(old_pos)

	# Place the tile at the new position
	tile_locations[grid_pos] = tile
	tile.draggable.home_position = grid_to_global_pos(grid_pos)


func move_tile(tile: Tile, new_pos: Vector2i) -> void:
	# Find the tile's current position
	var old_pos: Vector2i = find_tile_pos(tile)

	# Only allow moving tiles that are already in the grid
	if not is_grid_pos_valid(old_pos):
		return

	# Check that the new position is within the grid boundaries
	if not is_grid_pos_valid(new_pos):
		return

	# If the new position is the same as the current, do nothing
	if old_pos == new_pos:
		return

	# If the target grid position is occupied
	if not is_grid_pos_open(new_pos):
		var existing_tile: Tile = tile_locations[new_pos]

		# Don't swap with self
		if existing_tile == tile:
			_assign_tile_to_grid_pos(tile, new_pos) # Just reaffirm position
			return

		# Swap the tiles
		_assign_tile_to_grid_pos(existing_tile, old_pos)
		_assign_tile_to_grid_pos(tile, new_pos)
	else:
		# Target position is open, just move the tile there
		_assign_tile_to_grid_pos(tile, new_pos)


func global_pos_to_grid(global_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = global_pos - global_position
	return Vector2i(
		floor(local_pos.x / grid_spacing),
		floor(local_pos.y / grid_spacing)
	)
	
	
func grid_to_global_pos(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		((grid_pos.x + 0.5) * grid_spacing) + global_position.x,
		((grid_pos.y + 0.5) * grid_spacing) + global_position.y
	)
	
	
func grid_to_local_pos(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		((grid_pos.x + 0.5) * grid_spacing),
		((grid_pos.y + 0.5) * grid_spacing)
	)


func is_grid_pos_open(grid_pos: Vector2i) -> bool:
	return not tile_locations.has(grid_pos)


func _drop_tile_on_grid_pos(tile_draggable: Draggable, global_drop_pos: Vector2) -> void:
	# Get the grid position of the drop
	var grid_drop_pos: Vector2i = global_pos_to_grid(global_drop_pos)
	var tile_to_move: Tile = tile_draggable.get_parent()
	var old_grid_pos: Vector2i = find_tile_pos(tile_to_move) # Find where the tile was, if anywhere

	# Check that the position is within the grid boundaries
	if not is_grid_pos_valid(grid_drop_pos):
		# If dropped outside the grid:
		if not is_grid_pos_valid(old_grid_pos):
			# Tile was not in the grid before, find a new empty spot
			var available_pos = find_available_grid_pos()
			if is_grid_pos_valid(available_pos):
				_assign_tile_to_grid_pos(tile_to_move, available_pos)
			else:
				# No space left, snap back to origin (or handle error)
				tile_draggable.snap_back()
		else:
			# Tile was already in the grid, snap it back to its old position
			tile_draggable.snap_back() # Draggable handles snapping back to home_position
		return

	# If the target grid position is occupied
	if not is_grid_pos_open(grid_drop_pos):
		var existing_tile: Tile = tile_locations[grid_drop_pos]

		# Don't swap with self
		if existing_tile == tile_to_move:
			_assign_tile_to_grid_pos(tile_to_move, grid_drop_pos) # Just reaffirm position
			return

		# Determine where the existing tile should go
		var target_pos_for_existing_tile: Vector2i
		if is_grid_pos_valid(old_grid_pos):
			# If the moving tile came from a valid grid spot, swap them
			target_pos_for_existing_tile = old_grid_pos
		else:
			# If the moving tile came from outside, find a new spot for the existing tile
			target_pos_for_existing_tile = find_available_grid_pos()

		# Check if we found a place for the existing tile
		if is_grid_pos_valid(target_pos_for_existing_tile):
			_assign_tile_to_grid_pos(existing_tile, target_pos_for_existing_tile)
			_assign_tile_to_grid_pos(tile_to_move, grid_drop_pos)
			
			Events.tile_manually_moved.emit(existing_tile)
			Events.tile_manually_moved.emit(tile_to_move)
		else:
			# No valid spot to move the existing tile, snap the moving tile back
			tile_draggable.snap_back()

	else:
		# Target position is open, just move the tile there
		_assign_tile_to_grid_pos(tile_to_move, grid_drop_pos)
		Events.tile_manually_moved.emit(tile_to_move)


func find_available_grid_pos() -> Vector2i:
	for y in range(grid_height):
		for x in range(grid_width):
			if is_grid_pos_open(Vector2i(x,y)):
				return Vector2i(x,y)
	return Vector2i(-1, -1)


func is_grid_pos_valid(pos: Vector2i) -> bool:
	return pos.x >= 0\
		and pos.x < grid_width\
		and pos.y >= 0\
		and pos.y < grid_height


func find_tile_pos(tile_to_find: Tile) -> Vector2i:
	for pos in tile_locations.keys():
		if tile_locations[pos] == tile_to_find:
			return pos
	return Vector2i(-1, -1) # Return invalid position if not found


func push_tile(tile: Tile, direction: Vector2i) -> void:
	# Only allow cardinal directions
	var allowed_directions = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	if not direction in allowed_directions:
		printerr("TileGrid is trying to push a tile not in a cardinal direction!")
		return

	# Find the tile's current position
	var start_pos: Vector2i = find_tile_pos(tile)
	if not is_grid_pos_valid(start_pos):
		return

	# Gather all tiles in the push line
	var positions: Array = []
	var pos = start_pos
	while is_grid_pos_valid(pos) and tile_locations.has(pos):
		positions.append(pos)
		pos += direction

	# The next position after the last tile in the line
	var end_pos: Vector2i = positions[-1] + direction

	# Check if the end position is valid and open
	if not (is_grid_pos_valid(end_pos) and is_grid_pos_open(end_pos)):
		return

	# Move all tiles in the line, starting from the end
	for i in range(positions.size() - 1, -1, -1):
		var from_pos = positions[i]
		var to_pos = from_pos + direction
		var t = tile_locations[from_pos]
		_assign_tile_to_grid_pos(t, to_pos)
		
		Events.tile_pushed.emit(t)


func _add_status_to_grid_pos(grid_pos: Vector2i, status: GridStatusEffect) -> void:
	for status_effect: GridStatusEffect in grid_status_effects.keys():
		if status_effect.get_script() == status.get_script() and \
		grid_status_effects[status_effect] == grid_pos:
			print("status already affects this grid pos: ", status.get_script())
			return
			
	if not is_grid_pos_valid(grid_pos):
		printerr("Attempting to add a status to an invalid grid position: ", grid_pos)
		return
	
	status.position = grid_to_local_pos(grid_pos)
	add_child(status)
	
	grid_status_effects[status] = grid_pos


func get_status_effects_at_grid_pos(grid_pos: Vector2i) -> Array[GridStatusEffect]:
	var status_effects: Array[GridStatusEffect] = []
	
	for status_effect: GridStatusEffect in grid_status_effects.keys():
		if grid_status_effects[status_effect] == grid_pos:
			status_effects.append(status_effect)
			
	# Sort the status effects by priority (highest priority first)
	status_effects.sort_custom(func(a, b): return a.status_effect_priority > b.status_effect_priority)
			
	return status_effects
	
	
func clear_status_effects() -> void:
	for status_effect: GridStatusEffect in grid_status_effects.keys():
		if status_effect and is_instance_valid(status_effect):
			status_effect.queue_free()
		
	grid_status_effects.clear()
