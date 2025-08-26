class_name AmplifierTileStatus
extends GridStatusEffect

## The amplifier tile that this status effect is attached to
## Set this before adding to the game tree
var amplifier_tile: Tile = null

## The amplifier status nodes that have been created
var amplifier_statuses: Array[AmplifierStatus] = []

## The scene for the actual amplifier status effects
var amplfier_status_scene: PackedScene = preload("uid://c37hnomb8a6x1")


func _ready() -> void:	
	# Connect to tile movement events so we 
	# can track the amplifier tile
	Events.tile_manually_moved.connect(_on_tile_moved)
	Events.tile_pushed.connect(_on_tile_moved)
	
	_add_self_to_grid()
	_apply_amplification()


func _add_self_to_grid() -> void:
	if not amplifier_tile:
		return
		
	var current_grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(amplifier_tile)
	if Globals.tile_grid.is_grid_pos_valid(current_grid_pos):
		Globals.tile_grid.grid_status_effects[self as GridStatusEffect] = current_grid_pos
		

func _apply_amplification() -> void:
	if not amplifier_tile:
		return
	
	# Clear previous amplified positions
	_clear_amplification()
	
	var current_grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(amplifier_tile)
	
	# Calculate positions above and below
	var above_pos: Vector2i = current_grid_pos + Vector2i(0, -1)
	var below_pos: Vector2i = current_grid_pos + Vector2i(0, 1)
	
	# Apply amplification to valid positions
	if Globals.tile_grid.is_grid_pos_valid(above_pos):
		_add_amplifier_status_at_position(above_pos)
	
	if Globals.tile_grid.is_grid_pos_valid(below_pos):
		_add_amplifier_status_at_position(below_pos, true)


func _add_amplifier_status_at_position(grid_pos: Vector2i, flip: bool = false) -> void:
	var amplifier_status: AmplifierStatus = amplfier_status_scene.instantiate()
	amplifier_statuses.append(amplifier_status)
	
	if flip:
		amplifier_status.rotate(PI)
	
	Events.add_status_to_grid_pos.emit(grid_pos, amplifier_status)


func _clear_amplification() -> void:
	for amplifier_status: AmplifierStatus in amplifier_statuses:
		if is_instance_valid(amplifier_status):
			amplifier_status.queue_free()


func _on_tile_moved(moved_tile: Tile) -> void:
	if moved_tile == amplifier_tile:
		# Remove self from the tile_grid's dictionary
		if Globals.tile_grid.grid_status_effects.keys().has(self):
			Globals.tile_grid.grid_status_effects.erase(self)
		
		_add_self_to_grid()
		_clear_amplification()
		_apply_amplification()


func _exit_tree() -> void:
	_clear_amplification()
	
	# Disconnect from movement events
	if Events.tile_manually_moved.is_connected(_on_tile_moved):
		Events.tile_manually_moved.disconnect(_on_tile_moved)
	if Events.tile_pushed.is_connected(_on_tile_moved):
		Events.tile_pushed.disconnect(_on_tile_moved)
	
	# Call parent _exit_tree to remove from grid_status_effects
	super._exit_tree()
