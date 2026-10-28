extends "res://test/helpers/die_fighter_test.gd"
## Ships: the catalog finds them, and a TileGrid shaped by a ship's layout
## treats the holes in it as off the grid.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var grid: TileGrid


## A 3x2 grid with a hole in the middle of its top row:
##   X . X
##   X X X
func _holed_grid() -> TileGrid:
	var holed: TileGrid = TileGrid.new()
	var cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	]
	holed.set_cells(cells)
	add_child_autofree(holed)
	return holed


func _place(on: TileGrid, pos: Vector2i) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	on._assign_tile_to_grid_pos(tile, pos)
	return tile


func test_the_catalog_lists_the_default_ship_first() -> void:
	var ships: Array[ShipResource] = ShipCatalog.all()
	assert_gt(ships.size(), 0)
	assert_eq(ships[0].id, ShipCatalog.DEFAULT_ID)


func test_every_ship_is_complete() -> void:
	var ids: Dictionary = {}
	for ship: ShipResource in ShipCatalog.all():
		assert_false(ids.has(ship.id), "%s: ids are unique" % ship.id)
		ids[ship.id] = true
		assert_ne(ship.display_name, "", "%s has a name" % ship.id)
		assert_not_null(ship.starting_save, "%s has a starting kit" % ship.id)
		var cells: Array[Vector2i] = ship.get_cells()
		for pos: Vector2i in ship.starting_save.tile_locations:
			assert_has(cells, pos, "%s: starting tile at %s is on a cell" % [ship.id, pos])


func test_an_unknown_ship_falls_back_to_the_default() -> void:
	assert_eq(ShipCatalog.find(&"no_such_ship").id, ShipCatalog.DEFAULT_ID)
	assert_eq(ShipCatalog.find(&"").id, ShipCatalog.DEFAULT_ID)


func test_the_default_ship_keeps_the_5x3_grid() -> void:
	grid = TileGrid.new()
	add_child_autofree(grid)
	assert_eq(grid.get_cells().size(), 15)
	assert_true(grid.is_grid_pos_valid(Vector2i(4, 2)))
	assert_false(grid.is_grid_pos_valid(Vector2i(5, 0)))


func test_a_hole_is_not_on_the_grid() -> void:
	grid = _holed_grid()
	assert_false(grid.is_grid_pos_valid(Vector2i(1, 0)))
	assert_true(grid.is_grid_pos_valid(Vector2i(1, 1)))
	assert_eq(grid.grid_width, 3)
	assert_eq(grid.grid_height, 2)


func test_free_cells_skip_holes() -> void:
	grid = _holed_grid()
	_place(grid, Vector2i(0, 0))
	assert_eq(grid.find_available_grid_pos(), Vector2i(2, 0))


func test_a_push_stops_at_a_hole() -> void:
	grid = _holed_grid()
	var tile: Tile = _place(grid, Vector2i(0, 0))
	assert_false(grid.can_push_tile(tile, Vector2i(1, 0)))
	assert_true(grid.can_push_tile(tile, Vector2i(0, 1)))


func test_only_cells_get_empty_sockets() -> void:
	grid = _holed_grid()
	assert_null(grid.get_empty_cell_sprite(Vector2i(1, 0)))
	assert_not_null(grid.get_empty_cell_sprite(Vector2i(1, 1)))
