@tool
class_name TileGrid
extends Node2D

var grid_width: int = 5
var grid_height: int = 3
var grid_spacing: int = 24

var tile_locations: Dictionary[Tile, Vector2i]
@export var tile_scene: PackedScene

@export var empty_cell_texture: Texture2D

signal tile_activation_complete()
signal tile_moved()


func _ready() -> void:
	_setup_grid_graphics()
	
	
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
	
	
func setup_tiles(_tile_locations: Dictionary[TileResource, Vector2i]) -> void:
	for tile_resource in _tile_locations.keys():
		# Create a tile scene and give it the proper resource
		var tile = tile_scene.instantiate()
		tile.tile_resource = tile_resource
		
		# Find the tile's position in the grid and the world
		var tile_grid_pos: Vector2i = _tile_locations[tile_resource]
		var tile_world_pos: Vector2 = Vector2(
			(tile_grid_pos.x + 0.5) * grid_spacing,
			(tile_grid_pos.y + 0.5) * grid_spacing
		)
		
		# Set up the tile's initial position
		tile.global_position = global_position + tile_world_pos
		
		# Set the tile within the grid representation
		_assign_tile_to_grid_pos(tile as Tile, tile_grid_pos)
		
		# Connect the tile's drag ended signal to the function to snap it to the grid
		tile.draggable.drag_ended.connect(_drop_tile_on_grid_pos)
		tile.tile_activation_complete.connect(self.tile_activation_complete.emit)
		
		add_child(tile)


func _assign_tile_to_grid_pos(tile: Tile, grid_pos: Vector2i) -> void:
	if tile in tile_locations.keys():
		tile_locations.erase(tile)
		
	tile_locations[tile] = grid_pos
	
	tile.draggable.home_position = _grid_to_global_pos(grid_pos)
	
		
func _global_pos_to_grid(global_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = global_pos - global_position
	return Vector2i(
		floor(local_pos.x / grid_spacing),
		floor(local_pos.y / grid_spacing)
	)
	
	
func _grid_to_global_pos(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		((grid_pos.x + 0.5) * grid_spacing) + global_position.x,
		((grid_pos.y + 0.5) * grid_spacing) + global_position.y
	)


func _is_grid_pos_open(grid_pos: Vector2i) -> bool:
	return not tile_locations.values().has(grid_pos)


func _drop_tile_on_grid_pos(tile_draggable: Draggable, global_drop_pos: Vector2) -> void:
	# Get the grid position of the drop
	var grid_drop_pos: Vector2i = _global_pos_to_grid(global_drop_pos)
	var tile_to_move: Tile = tile_draggable.get_parent()
	
	# Check that the position is within the grid
	if grid_drop_pos.x < 0 or grid_drop_pos.x >= grid_width\
	or grid_drop_pos.y < 0 or grid_drop_pos.y >= grid_height:
		if not tile_locations.has(tile_to_move):
			_assign_tile_to_grid_pos(tile_to_move, find_available_grid_pos())
		return
		
	# If the grid position is full, switch with the existing tile
	if not _is_grid_pos_open(grid_drop_pos):
		var old_grid_pos: Vector2i
		
		# If we're putting in a new tile, put the tile in the dropped location
		# and move the old tile to an open slot
		if not tile_locations.has(tile_to_move):
			old_grid_pos = find_available_grid_pos()
		else:
			old_grid_pos = tile_locations[tile_to_move]
			
		var existing_tile = tile_locations.find_key(grid_drop_pos)
		_assign_tile_to_grid_pos(existing_tile, old_grid_pos)
		
	# Move the tile to the desired grid position
	_assign_tile_to_grid_pos(tile_to_move, grid_drop_pos)
	tile_moved.emit()
	

func find_available_grid_pos() -> Vector2i:
	for y in range(grid_height):
		for x in range(grid_width):
			if _is_grid_pos_open(Vector2i(x,y)):
				return Vector2i(x,y)
	return Vector2i(-1, -1)
