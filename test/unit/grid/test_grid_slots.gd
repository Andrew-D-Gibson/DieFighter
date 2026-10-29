extends "res://test/helpers/die_fighter_test.gd"
## Sealed cells: part of the ship's layout, closed to tiles until a Grid Slot
## opens one, and treated as a hole until then.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const RUN_START: GameSaveResource = preload("res://Source/Resources/SaveResources/run_start.tres")

var grid: TileGrid


## The default 5x3 grid with only its middle 3x3 open.
func before_each() -> void:
	super()
	grid = TileGrid.new()
	add_child_autofree(grid)
	var open: Array[Vector2i] = []
	for y: int in 3:
		for x: int in range(1, 4):
			open.append(Vector2i(x, y))
	grid.set_open_cells(open)


func _place(pos: Vector2i) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	grid._assign_tile_to_grid_pos(tile, pos)
	return tile


func test_sealed_cells_are_off_the_grid() -> void:
	assert_eq(grid.get_cells().size(), 9)
	assert_eq(grid.get_locked_cells().size(), 6)
	assert_false(grid.is_grid_pos_valid(Vector2i(0, 1)))
	assert_true(grid.is_cell_locked(Vector2i(4, 2)))
	assert_true(grid.is_grid_pos_valid(Vector2i(1, 1)))


func test_sealing_keeps_the_layouts_shape() -> void:
	assert_eq(grid.grid_width, 5, "a sealed column still counts toward the width")
	assert_eq(grid.mirror_of(Vector2i(1, 0)), Vector2i(3, 0))


func test_a_push_stops_at_a_sealed_cell() -> void:
	var tile: Tile = _place(Vector2i(1, 1))
	assert_false(grid.can_push_tile(tile, Vector2i(-1, 0)))
	assert_true(grid.can_push_tile(tile, Vector2i(1, 0)))


func test_unlocking_opens_the_cell() -> void:
	assert_true(grid.unlock_cell(Vector2i(0, 1)))
	assert_true(grid.is_grid_pos_valid(Vector2i(0, 1)))
	assert_false(grid.is_cell_locked(Vector2i(0, 1)))
	assert_eq(grid.get_cells().size(), 10)
	assert_eq(grid.get_cells()[3], Vector2i(0, 1), "open cells stay in reading order")


func test_only_a_sealed_cell_unlocks() -> void:
	assert_false(grid.unlock_cell(Vector2i(2, 1)), "already open")
	assert_false(grid.unlock_cell(Vector2i(7, 7)), "not on the ship")


func test_unlocking_announces_the_cell() -> void:
	watch_signals(grid)
	grid.unlock_cell(Vector2i(4, 0))
	assert_signal_emitted_with_parameters(grid, "cell_unlocked", [Vector2i(4, 0)])


func test_a_sealed_cell_is_found_under_a_point() -> void:
	assert_eq(grid.locked_cell_at(grid.grid_to_global_pos(Vector2i(4, 1))), Vector2i(4, 1))
	assert_eq(grid.locked_cell_at(grid.grid_to_global_pos(Vector2i(2, 1))), Vector2i(-1, -1))


func test_opening_nothing_opens_everything() -> void:
	var none: Array[Vector2i] = []
	grid.set_open_cells(none)
	assert_eq(grid.get_cells().size(), 15)
	assert_false(grid.has_locked_cell())


func test_a_full_open_grid_still_has_room_to_grow() -> void:
	for cell: Vector2i in grid.get_cells():
		_place(cell)
	assert_false(grid.has_free_cell())
	assert_true(grid.has_locked_cell())


func test_slot_targets_light_only_while_carried() -> void:
	grid.show_slot_targets(true)
	for cell: Vector2i in grid.get_locked_cells():
		assert_true(grid._locked_cells[cell].get_node("Target").visible)
	grid.show_slot_targets(false)
	for cell: Vector2i in grid.get_locked_cells():
		assert_false(grid._locked_cells[cell].get_node("Target").visible)


func test_the_die_fighter_starts_on_its_middle_3x3() -> void:
	assert_eq(RUN_START.unlocked_cells.size(), 9)
	for cell: Vector2i in RUN_START.unlocked_cells:
		assert_between(cell.x, 1, 3)
	for pos: Vector2i in RUN_START.tile_locations:
		assert_has(RUN_START.unlocked_cells, pos, "starting tile at %s sits on an open cell" % pos)
