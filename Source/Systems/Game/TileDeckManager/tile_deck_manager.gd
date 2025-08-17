class_name TileDeckManager
extends Node2D

@export var deck_of_tiles: Array[TileResource]
var deck_at_start_of_scenario: Array[TileResource]
@export var discard_tiles: Array[TileResource]
@export var current_hand_of_tiles: Array[Tile]
var hand_option_locks: Array[HandOptionLock]
var tile_scene: PackedScene = preload("uid://delq7kb5loqt2")
var hand_option_lock_scene: PackedScene = preload("uid://4cq11kckae42")

@onready var _raised: bool = false
@onready var _starting_position: Vector2 = global_position
var _raised_offset: int = 153

func _ready() -> void:
	Globals.deck_manager = self
	Events.load_game_save.connect(_load_game_save)
	Events.start_scenario.connect(_on_scenario_start)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.player_turn_over.connect(_on_player_turn_over)
	Events.jump.connect(_on_jump)
	Events.hand_option_unlock.connect(_on_hand_option_unlock)
	Events.add_tile_to_discard.connect(_on_add_tile_to_discard)
	Events.player_out_of_dice.connect(_lower)
	
	
func _print_deck() -> void:
	for tile_resource in deck_of_tiles:
		print(tile_resource.tile_name)
	
	
func _load_game_save(current_game_save: GameSaveResource) -> void:
	deck_of_tiles = current_game_save.deck_of_tiles
	
	
func _on_scenario_start() -> void:
	shuffle_deck()
	deck_at_start_of_scenario = deck_of_tiles

	
func _on_player_turn_start() -> void:
	if len(deck_of_tiles) == 0:
		_shuffle_discard_into_deck()
		
	_draw_new_hand()
	
	if Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		_raise()
	
	
func _on_player_turn_over() -> void:
	_lower()
	_put_current_hand_in_discard()
	
		
func _on_jump() -> void:
	_lower()
	_reassemble_full_deck()
	
	
func _on_hand_option_unlock(option_num: int) -> void:
	current_hand_of_tiles[option_num-1].draggable.dragging_allowed = true
	current_hand_of_tiles[option_num-1].draggable.floating_enabled = true
	
	
func _on_add_tile_to_discard(tile: Tile) -> void:
	discard_tiles.push_front(tile.tile_resource)
	tile.queue_free()
	
	
func _reassemble_full_deck() -> void:
	# Grab the tiles from the current hand and discard
	_put_current_hand_in_discard()
	_shuffle_discard_into_deck()
	
	# Grab the tiles from the tile grid
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		if tile and tile is Tile:
			deck_of_tiles.append(tile.tile_resource)
			tile.queue_free()
			
	Globals.tile_grid.tile_locations.clear()
	
	
func _shuffle_discard_into_deck() -> void:
	deck_of_tiles.append_array(discard_tiles)
	deck_of_tiles.shuffle()
	
	discard_tiles.clear()
	
	
func _put_current_hand_in_discard() -> void:
	for unchosen_tile: Tile in current_hand_of_tiles:
		if unchosen_tile and unchosen_tile is Tile:
			discard_tiles.push_front(unchosen_tile.tile_resource)
			unchosen_tile.queue_free()
	current_hand_of_tiles.clear()
		
	
func _draw_new_hand() -> void:
	for tile: Tile in current_hand_of_tiles:
		if tile and tile is Tile:
			tile.queue_free()
	current_hand_of_tiles.clear()
	
	for lock: HandOptionLock in hand_option_locks:
		if lock and lock is HandOptionLock:
			lock.queue_free()
	hand_option_locks.clear()
	
	var tile_spacing: int = 25
	var tile_start_offset: Vector2 = Vector2(-9, -40)
	var lock_start_offset: Vector2 = Vector2(12, -39)
	for i: int in range(6):
		if len(deck_of_tiles) == 0:
			current_hand_of_tiles.append(null)
			hand_option_locks.append(null)
			break
			
		# Add a new tile
		var tile_option: Tile = tile_scene.instantiate()
		
		tile_option.tile_resource = deck_of_tiles[0]
		deck_of_tiles.remove_at(0)
		
		add_child(tile_option)
		
		tile_option.draggable.drag_started.connect(Events.show_systems.emit)
		tile_option.draggable.drag_ended.connect(_on_option_tile_drag_ended)
		
		# Spawn the tile at their "lowered" position
		tile_option.global_position = _starting_position + \
			tile_start_offset + \
			Vector2(0, i * tile_spacing)
			
		# Set the tile's home to their "raised" position
		tile_option.draggable.home_position = tile_option.global_position + \
			Vector2(0, -_raised_offset)
		
		tile_option.draggable.emit_reached_new_home = false
		tile_option.draggable.floating_enabled = false
		
		tile_option.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		tile_option.draggable.dragging_allowed = false
		
		tile_option.can_accept_dice.enabled = false
		
		current_hand_of_tiles.append(tile_option)
		
		
		# Add the option lock
		var hand_option_lock: HandOptionLock = hand_option_lock_scene.instantiate()
		hand_option_lock.set_unlock_die_value(i + 1)
		add_child(hand_option_lock)
		hand_option_lock.global_position = global_position + lock_start_offset + Vector2(0, i * tile_spacing)
		hand_option_locks.append(hand_option_lock)
		
	
func _on_option_tile_drag_ended(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - %BoundingBox.global_position
	# Don't do anything if the drag ended within the bounding box
	if %BoundingBox.shape.get_rect().has_point(local_end_position):
		return
		
	var chosen_tile: Tile = draggable.get_parent()
	
	chosen_tile.draggable.drag_started.disconnect(Events.show_systems.emit)
	chosen_tile.draggable.drag_ended.disconnect(_on_option_tile_drag_ended)
	chosen_tile.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
	chosen_tile.draggable.dragging_allowed = false
	chosen_tile.draggable.floating_enabled = false
	chosen_tile.can_accept_dice.enabled = true
	
	var hand_index: int = current_hand_of_tiles.find(chosen_tile)
	current_hand_of_tiles[hand_index] = null
	chosen_tile.reparent(Globals.tile_grid, true)
	
	Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)
	
	
func shuffle_deck() -> void:
	deck_of_tiles.shuffle()
	
	
func _raise() -> void:
	if not _raised:
		_toggle_raised()
		

func _lower() -> void:
	if _raised:
		_toggle_raised()
		
	
func _toggle_raised() -> void:
	_raised = !_raised
	
	if not _raised:
		for tile: Tile in current_hand_of_tiles:
			if tile and tile is Tile:
				tile.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	
	await _update_ui()
	
	if _raised:
		for tile: Tile in current_hand_of_tiles:
			if tile and tile is Tile:
				tile.draggable.state = Draggable.DragState.DEFAULT
	
	
func _update_ui() -> void:
	var desired_pos: Vector2 = _starting_position
	if _raised:
		desired_pos += Vector2(0, -_raised_offset)

	# Calculate how far the raising motion needs to go
	# as a proportion of the total distance
	var normalized_vertical_distance_to_cover: float = abs(global_position.y - desired_pos.y)/_raised_offset

	# Set the tween time to be proportional to the distance needed to cover
	# This means the tween should move the node at around the same speed,
	# regardless of the distance needed to cover
	var tween_time: float = 0.75 * normalized_vertical_distance_to_cover
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(
		self,
		"global_position",
		desired_pos,
		tween_time
	).set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
