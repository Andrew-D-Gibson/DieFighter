class_name TileGrid
extends Node2D

## The only directions a tile can be pushed.
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

@export var grid_width: int = 5
@export var grid_height: int = 3
@export var grid_spacing: int = 24

var tile_scene: PackedScene = preload("uid://delq7kb5loqt2")
var tile_locations: Dictionary[Vector2i, Tile] = {}

@export var empty_cell_texture: Texture2D


func _ready() -> void:
	Globals.tile_grid = self
	
	Events.load_game_save.connect(_load_game_save)
	# Through a lambda, not Events.show_systems.emit directly: that callable
	# belongs to the autoload, so the connection would outlive this scene and
	# the next game scene's identical connect() would fail as a duplicate.
	Events.start_combat.connect(func() -> void: Events.show_systems.emit())
	Events.start_scenario.connect(_restore_tile_uses)

	_setup_grid_graphics()
	
	
func _load_game_save(game_save: GameSaveResource) -> void:
	_setup_tiles(game_save.tile_locations)

	# Counters a tile keeps across scenarios (Tile.effect_data) aren't part of
	# its resource, so a tile rebuilt on load needs them handed back.
	for pos: Vector2i in game_save.tile_effect_data:
		if tile_locations.has(pos):
			tile_locations[pos].effect_data.assign(game_save.tile_effect_data[pos])


## uses_remaining per tile, keyed "x,y", for a mid-scenario save.
func capture_tile_uses() -> Dictionary:
	var uses: Dictionary = {}
	for pos: Vector2i in tile_locations:
		uses["%d,%d" % [pos.x, pos.y]] = tile_locations[pos].uses_remaining
	return uses


## Continuing a save taken partway through a scenario: tiles spent before the
## save stay spent. Deferred a frame because every tile resets its own uses on
## start_scenario, and tiles connect after this node does.
func _restore_tile_uses() -> void:
	if not Globals.state_manager:
		return
	var saved: Dictionary = Globals.state_manager.get_restore().get("tile_uses", {})
	if saved.is_empty():
		return
	await get_tree().process_frame
	for key: Variant in saved:
		var parts: PackedStringArray = str(key).split(",")
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		if tile_locations.has(pos):
			tile_locations[pos].uses_remaining = int(saved[key])
	
	
func _setup_grid_graphics() -> void:
	for x: int in range(grid_width):
		for y: int in range(grid_height):
			# Add an empty cell sprite
			var empty_cell: Sprite2D = Sprite2D.new()
			empty_cell.texture = empty_cell_texture
			empty_cell.z_index = -1
			empty_cell.position = Vector2(
				(x + 0.5) * grid_spacing,		# The added 0.5 is to offset the tiles 
				(y + 0.5) * grid_spacing		# to their top left, rather than their center 
			)
			
			add_child(empty_cell)
	
	
func _setup_tiles(_tile_locations: Dictionary[Vector2i, TileResource]) -> void:
	# Clear existing tiles before setting up new ones, if any
	for pos: Vector2i in tile_locations.keys():
		if is_instance_valid(tile_locations[pos]):
			tile_locations[pos].queue_free()
	tile_locations.clear()

	for tile_grid_pos: Vector2i in _tile_locations.keys():
		var tile_resource: TileResource = _tile_locations[tile_grid_pos]
		
		var tile: Tile = create_tile(tile_resource)
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


func create_tile(tile_resource: TileResource) -> Tile:
	var tile: Tile = tile_scene.instantiate()
	tile.tile_resource = tile_resource
	return tile


func receive_tile(tile: Tile, drop_position: Vector2) -> void:
	tile.draggable.floating_enabled = false
	tile.draggable.drag_ended.connect(_drop_tile_on_grid_pos)
	tile.reparent(self, true)
	_drop_tile_on_grid_pos(tile.draggable, drop_position)


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
			var available_pos: Vector2i = find_available_grid_pos()
			if is_grid_pos_valid(available_pos):
				_assign_tile_to_grid_pos(tile_to_move, available_pos)
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
		# Target position is open, just move the tile there
		_assign_tile_to_grid_pos(tile_to_move, grid_drop_pos)
		Events.tile_manually_moved.emit(tile_to_move)


func find_available_grid_pos() -> Vector2i:
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			if is_grid_pos_open(Vector2i(x,y)):
				return Vector2i(x,y)
	return Vector2i(-1, -1)


func is_grid_pos_valid(pos: Vector2i) -> bool:
	return pos.x >= 0\
		and pos.x < grid_width\
		and pos.y >= 0\
		and pos.y < grid_height


func find_tile_pos(tile_to_find: Tile) -> Vector2i:
	for pos: Vector2i in tile_locations.keys():
		if tile_locations[pos] == tile_to_find:
			return pos
	return Vector2i(-1, -1) # Return invalid position if not found


## Whether pushing this tile that way would actually move anything: the whole
## line of tiles being shoved needs an open cell to slide into. Callers that get
## to choose a direction (a random shove, say) can use this to pick one that
## isn't a silent no-op.
func can_push_tile(tile: Tile, direction: Vector2i) -> bool:
	if not direction in CARDINAL_DIRECTIONS:
		return false

	var start_pos: Vector2i = find_tile_pos(tile)
	if not is_grid_pos_valid(start_pos):
		return false

	var pos: Vector2i = start_pos
	while is_grid_pos_valid(pos) and tile_locations.has(pos):
		pos += direction

	return is_grid_pos_valid(pos) and is_grid_pos_open(pos)


func push_tile(tile: Tile, direction: Vector2i) -> void:
	if not direction in CARDINAL_DIRECTIONS:
		printerr("TileGrid is trying to push a tile not in a cardinal direction!")
		return

	if not can_push_tile(tile, direction):
		return

	# Gather all tiles in the push line
	var start_pos: Vector2i = find_tile_pos(tile)
	var positions: Array = []
	var pos: Vector2i = start_pos
	while is_grid_pos_valid(pos) and tile_locations.has(pos):
		positions.append(pos)
		pos += direction

	# Move all tiles in the line, starting from the end
	for i: int in range(positions.size() - 1, -1, -1):
		var from_pos: Vector2i = positions[i]
		var to_pos: Vector2i = from_pos + direction
		var t: Tile = tile_locations[from_pos]
		_assign_tile_to_grid_pos(t, to_pos)
		
		Events.tile_pushed.emit(t)
