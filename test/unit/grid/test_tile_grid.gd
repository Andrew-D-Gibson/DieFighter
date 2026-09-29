extends "res://test/helpers/die_fighter_test.gd"
## TileGrid bookkeeping: coordinates, placement, swapping and pushing.
##
## Tiles are bare tile.tscn instances with no resource, kept out of the tree:
## the grid only needs their identity and Draggable, and a tile's own _ready()
## reaches for GameStateManager.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var grid: TileGrid


func before_each() -> void:
	super()
	grid = TileGrid.new()
	grid.position = Vector2(100, 50)
	add_child_autofree(grid)


## Puts a tile straight into a cell. The public entry points (receive_tile,
## save loading) involve drag-and-drop and resource setup; placement itself is
## what's under test here.
func _place(pos: Vector2i) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	grid._assign_tile_to_grid_pos(tile, pos)
	return tile


func test_grid_bounds() -> void:
	assert_true(grid.is_grid_pos_valid(Vector2i(0, 0)))
	assert_true(grid.is_grid_pos_valid(Vector2i(4, 2)))
	assert_false(grid.is_grid_pos_valid(Vector2i(5, 0)))
	assert_false(grid.is_grid_pos_valid(Vector2i(0, 3)))
	assert_false(grid.is_grid_pos_valid(Vector2i(-1, 0)))


func test_grid_and_world_coordinates_round_trip() -> void:
	for x: int in grid.grid_width:
		for y: int in grid.grid_height:
			var cell := Vector2i(x, y)
			assert_eq(grid.global_pos_to_grid(grid.grid_to_global_pos(cell)), cell)


func test_a_point_anywhere_in_a_cell_maps_to_that_cell() -> void:
	var corner: Vector2 = grid.global_position + Vector2(grid.grid_spacing, 0)
	assert_eq(grid.global_pos_to_grid(corner), Vector2i(1, 0))
	assert_eq(grid.global_pos_to_grid(corner - Vector2(0.01, 0)), Vector2i(0, 0))


func test_find_available_fills_row_by_row() -> void:
	_place(Vector2i(0, 0))
	_place(Vector2i(1, 0))
	assert_eq(grid.find_available_grid_pos(), Vector2i(2, 0))


func test_find_available_on_a_full_grid_is_invalid() -> void:
	for x: int in grid.grid_width:
		for y: int in grid.grid_height:
			_place(Vector2i(x, y))
	assert_false(grid.is_grid_pos_valid(grid.find_available_grid_pos()))


func test_move_to_an_empty_cell() -> void:
	var tile := _place(Vector2i(0, 0))
	grid.move_tile(tile, Vector2i(3, 1))
	assert_eq(grid.find_tile_pos(tile), Vector2i(3, 1))
	assert_true(grid.is_grid_pos_open(Vector2i(0, 0)))
	assert_eq(tile.draggable.home_position, grid.grid_to_global_pos(Vector2i(3, 1)))


func test_move_onto_another_tile_swaps_them() -> void:
	var a := _place(Vector2i(0, 0))
	var b := _place(Vector2i(1, 0))
	grid.move_tile(a, Vector2i(1, 0))
	assert_eq(grid.find_tile_pos(a), Vector2i(1, 0))
	assert_eq(grid.find_tile_pos(b), Vector2i(0, 0))


func test_moves_off_the_grid_are_ignored() -> void:
	var tile := _place(Vector2i(0, 0))
	grid.move_tile(tile, Vector2i(9, 9))
	assert_eq(grid.find_tile_pos(tile), Vector2i(0, 0))


func test_push_slides_the_whole_line() -> void:
	var a := _place(Vector2i(0, 1))
	var b := _place(Vector2i(1, 1))
	watch_signals(Events)
	grid.push_tile(a, Vector2i.RIGHT)
	assert_eq(grid.find_tile_pos(a), Vector2i(1, 1))
	assert_eq(grid.find_tile_pos(b), Vector2i(2, 1))
	assert_signal_emit_count(Events, "tile_pushed", 2)


func test_push_into_the_wall_does_nothing() -> void:
	var a := _place(Vector2i(3, 0))
	var b := _place(Vector2i(4, 0))
	assert_false(grid.can_push_tile(a, Vector2i.RIGHT))
	grid.push_tile(a, Vector2i.RIGHT)
	assert_eq(grid.find_tile_pos(a), Vector2i(3, 0))
	assert_eq(grid.find_tile_pos(b), Vector2i(4, 0))


func test_diagonal_pushes_are_refused() -> void:
	var tile := _place(Vector2i(1, 1))
	assert_false(grid.can_push_tile(tile, Vector2i(1, 1)))


func test_tiles_outside_the_grid_cannot_be_pushed() -> void:
	var loose: Tile = autofree(TILE_SCENE.instantiate())
	assert_false(grid.can_push_tile(loose, Vector2i.RIGHT))
