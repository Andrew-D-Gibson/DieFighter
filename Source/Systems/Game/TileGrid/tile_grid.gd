class_name TileGrid
extends Node2D

## The only directions a tile can be pushed.
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

## A tile on the grid was picked up. Anything that takes tiles off the player
## (the repair station buying them) uses it to show what it would pay.
signal tile_lifted(tile: Tile)
## A tile from the grid was let go of somewhere off the grid. It floats back to
## its cell unless a listener takes it.
signal tile_dropped_off_grid(tile: Tile, global_drop_pos: Vector2)

## The rectangle the grid's cells span. Set from the ship's layout, which may
## leave holes in it: ask is_grid_pos_valid() whether a tile can sit somewhere.
@export var grid_width: int = 5
@export var grid_height: int = 3
@export var grid_spacing: int = 24

var tile_scene: PackedScene = preload("uid://delq7kb5loqt2")
var tile_locations: Dictionary[Vector2i, Tile] = {}

## Tile activations so far this player turn, for tiles that scale with how
## busy the machine has been.
var activations_this_turn: int = 0

@export var empty_cell_texture: Texture2D

## Every cell a tile can sit in, top row first. Set from the ship in _ready,
## or by set_cells() before the grid enters the tree.
var _cells: Array[Vector2i] = []
var _cell_set: Dictionary[Vector2i, bool] = {}
var _empty_cell_sprites: Dictionary[Vector2i, Sprite2D] = {}
## The ship's own rules (ShipResource.behavior_scene), if it has any.
var ship_behavior: Node = null


func _ready() -> void:
	Globals.tile_grid = self
	
	Events.load_game_save.connect(_load_game_save)
	# Through a lambda, not Events.show_systems.emit directly: that callable
	# belongs to the autoload, so the connection would outlive this scene and
	# the next game scene's identical connect() would fail as a duplicate.
	Events.start_combat.connect(func() -> void: Events.show_systems.emit())
	Events.start_scenario.connect(_restore_tile_uses)
	Events.start_scenario.connect(_reset_activation_count)
	Events.player_turn_refresh.connect(_reset_activation_count)
	Events.tile_activated.connect(_count_activation)

	if _cells.is_empty():
		_apply_ship(Globals.current_ship())
	_setup_grid_graphics()
	_spawn_ship_behavior(Globals.current_ship())


## Shapes the grid to the ship: its cells, spacing and nudge within the viewer.
func _apply_ship(ship: ShipResource) -> void:
	if not ship:
		set_cells([])
		return
	grid_spacing = ship.grid_spacing
	position += ship.grid_offset
	grid_width = ship.grid_size.x
	grid_height = ship.grid_size.y
	set_cells(ship.get_cells())


## Sets which cells exist. Empty fills the grid_width x grid_height rectangle.
## Only before the grid enters the tree: the empty-cell art is laid in _ready.
func set_cells(cells: Array[Vector2i]) -> void:
	_cells.clear()
	_cell_set.clear()
	if cells.is_empty():
		for y: int in grid_height:
			for x: int in grid_width:
				_cells.append(Vector2i(x, y))
	else:
		_cells.assign(cells)
		grid_width = 0
		grid_height = 0
		for cell: Vector2i in _cells:
			grid_width = maxi(grid_width, cell.x + 1)
			grid_height = maxi(grid_height, cell.y + 1)
	for cell: Vector2i in _cells:
		_cell_set[cell] = true
	_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)


## Every cell a tile can sit in, top row first, left to right.
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## The dark socket drawn under an empty cell, for ship art that restyles it.
func get_empty_cell_sprite(pos: Vector2i) -> Sprite2D:
	return _empty_cell_sprites.get(pos)


func _spawn_ship_behavior(ship: ShipResource) -> void:
	if not ship or not ship.behavior_scene:
		return
	ship_behavior = ship.behavior_scene.instantiate()
	ship_behavior.name = "ShipBehavior"
	add_child(ship_behavior)



func _reset_activation_count() -> void:
	activations_this_turn = 0


func _count_activation(_tile: Tile) -> void:
	activations_this_turn += 1


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
	for cell: Vector2i in _cells:
		var empty_cell: Sprite2D = Sprite2D.new()
		empty_cell.texture = empty_cell_texture
		empty_cell.z_index = -1
		empty_cell.position = Vector2(
			(cell.x + 0.5) * grid_spacing,		# The added 0.5 is to offset the tiles 
			(cell.y + 0.5) * grid_spacing		# to their top left, rather than their center 
		)
		add_child(empty_cell)
		_empty_cell_sprites[cell] = empty_cell
	
	
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
		# Placed, not dropped: no landing thump.
		_assign_tile_to_grid_pos(tile as Tile, tile_grid_pos, false)

		_listen_to_drags(tile)


func create_tile(tile_resource: TileResource) -> Tile:
	var tile: Tile = tile_scene.instantiate()
	tile.tile_resource = tile_resource
	return tile


func receive_tile(tile: Tile, drop_position: Vector2) -> void:
	tile.on_offer = false
	tile.reparent(self, true)
	tile.update_dragging_allowed()
	tile.draggable.floating_enabled = false
	_listen_to_drags(tile)

	# Mid-fight the tiles already here are locked in place, so a tile taken
	# from a reward drops into the first free cell instead of shoving one aside.
	if Tile.grid_locked() and not is_grid_pos_open(global_pos_to_grid(drop_position)):
		drop_position = grid_to_global_pos(find_available_grid_pos())

	_drop_tile_on_grid_pos(tile.draggable, drop_position)


## Snaps the tile to the grid when it's let go, and reports it being picked
## up. Bound rather than a lambda, so the connection dies with the tile.
func _listen_to_drags(tile: Tile) -> void:
	tile.draggable.drag_ended.connect(_drop_tile_on_grid_pos)
	tile.draggable.drag_started.connect(_on_tile_lifted.bind(tile))


func _on_tile_lifted(tile: Tile) -> void:
	if find_tile_pos(tile) != Vector2i(-1, -1):
		tile_lifted.emit(tile)


func _assign_tile_to_grid_pos(tile: Tile, grid_pos: Vector2i, announce_arrival: bool = true) -> void:
	# Find the tile's current position, if it exists
	var old_pos: Vector2i = find_tile_pos(tile)

	# If the tile was already in the grid, remove its old entry
	if is_grid_pos_valid(old_pos):
		tile_locations.erase(old_pos)

	# Place the tile at the new position
	tile_locations[grid_pos] = tile
	tile.draggable.set_home(grid_to_global_pos(grid_pos), announce_arrival)


## Forgets a tile that is leaving the grid for good (destroyed by its own
## effect). Without this its cell keeps pointing at a freed node, and every
## neighbour lookup and the next save trip over it.
func forget_tile(tile: Tile) -> void:
	var pos: Vector2i = find_tile_pos(tile)
	if is_grid_pos_valid(pos):
		tile_locations.erase(pos)


## Takes a tile off the grid for good (sold). Any die it was holding goes
## back to the hand first, and anything the tile had put in play on the engine
## goes with it, so nothing keeps acting for a tile that's gone.
func remove_tile(tile: Tile) -> void:
	tile.release_held_dice()
	forget_tile(tile)
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		for mod: Modifier in engine.modifiers.duplicate():
			if mod.source == tile or mod.affected_node == tile:
				engine.remove_modifier(mod)
	tile.queue_free()


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
		else:
			tile_dropped_off_grid.emit(tile_to_move, global_drop_pos)
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


## Whether a new tile has somewhere to go. A shop or salvage tile taken onto a
## full grid would never get a cell.
func has_free_cell() -> bool:
	return is_grid_pos_valid(find_available_grid_pos())


func find_available_grid_pos() -> Vector2i:
	for cell: Vector2i in _cells:
		if is_grid_pos_open(cell):
			return cell
	return Vector2i(-1, -1)


## Whether a tile can sit here: one of the ship's cells, not a hole in its
## layout or off its edge.
func is_grid_pos_valid(pos: Vector2i) -> bool:
	return _cell_set.has(pos)


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


## Moves several grid tiles at once, keyed old cell -> new cell. Unlike
## move_tile() (one tile, swapping with whatever is there), every listed tile
## leaves before any arrives, so a whole loop of tiles can shift one cell
## along in a single step (the Carousel's ring). New cells must be valid and
## either listed as vacated or empty; anything else is skipped with an error.
## Homes move but the tiles don't announce their arrival: the caller decides
## how the motion looks (it can take the tiles over with MOVING_WITH_CODE).
## Emits no tile_pushed / tile_manually_moved: nothing was pushed or dragged.
func relocate_tiles(moves: Dictionary[Vector2i, Vector2i]) -> void:
	var moving: Dictionary[Vector2i, Tile] = {}
	for from_pos: Vector2i in moves:
		var to_pos: Vector2i = moves[from_pos]
		if not tile_locations.has(from_pos) or not is_grid_pos_valid(to_pos):
			push_error("TileGrid.relocate_tiles: bad move %s -> %s" % [from_pos, to_pos])
			continue
		if tile_locations.has(to_pos) and not moves.has(to_pos):
			push_error("TileGrid.relocate_tiles: %s is taken by a tile that isn't moving" % to_pos)
			continue
		moving[from_pos] = tile_locations[from_pos]
	for from_pos: Vector2i in moving:
		tile_locations.erase(from_pos)
	for from_pos: Vector2i in moving:
		var tile: Tile = moving[from_pos]
		tile_locations[moves[from_pos]] = tile
		tile.draggable.set_home(grid_to_global_pos(moves[from_pos]))
