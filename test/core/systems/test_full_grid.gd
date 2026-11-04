extends "res://test/helpers/die_fighter_test.gd"
## A tile taken from salvage or the shop needs a free cell. With none, the
## offer stands and nothing is paid, instead of the tile floating cell-less
## over the grid (found by the AutoPilot).

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const REWARD_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward.tscn")

## Well clear of the offer's window, where a player drops a choice to take it.
const _FAR_AWAY: Vector2 = Vector2(5000, 5000)

var grid: TileGrid


func before_each() -> void:
	super()
	grid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid


func _bare_tile() -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	return tile


func _fill_grid() -> void:
	for x: int in grid.grid_width:
		for y: int in grid.grid_height:
			grid._assign_tile_to_grid_pos(autofree(_bare_tile()), Vector2i(x, y))


## An offer holding one tile, wired the way Reward._present() wires a choice.
func _offer_with_tile() -> Array:
	var offer: Reward = add_child_autofree(REWARD_SCENE.instantiate())
	var tile: Tile = _bare_tile()
	offer.add_child(tile)
	tile.draggable.drag_started.connect(Events.show_systems.emit)
	tile.draggable.drag_ended.connect(offer._end_reward)
	return [offer, tile]


func test_a_grid_with_one_cell_left_has_room() -> void:
	_fill_grid()
	var last: Tile = grid.tile_locations[Vector2i(4, 2)]
	grid.forget_tile(last)
	assert_true(grid.has_free_cell())


func test_a_full_grid_has_no_room() -> void:
	_fill_grid()
	assert_false(grid.has_free_cell())


func test_salvage_refuses_a_tile_with_nowhere_to_go() -> void:
	_fill_grid()
	var parts: Array = _offer_with_tile()
	var offer: Reward = parts[0]
	var tile: Tile = parts[1]
	watch_signals(Events)
	offer._end_reward(tile.draggable, _FAR_AWAY)
	assert_eq(tile.get_parent(), offer, "still on offer")
	assert_false(offer.is_queued_for_deletion())
	assert_signal_emitted(Events, "error_text_popup")
	assert_true(tile.draggable.drag_ended.is_connected(offer._end_reward), "can be taken later")


func test_salvage_takes_a_tile_with_room() -> void:
	var parts: Array = _offer_with_tile()
	var offer: Reward = parts[0]
	var tile: Tile = parts[1]
	offer._end_reward(tile.draggable, _FAR_AWAY)
	assert_eq(tile.get_parent(), grid)
	assert_true(grid.is_grid_pos_valid(grid.find_tile_pos(tile)))
