extends "res://test/helpers/die_fighter_test.gd"
## The smart AutoPilot planning the grid (AutoPilotBuild): where a new tile
## goes, which sealed cell a Grid Slot opens, which drag improves the board,
## what a tile adds; and the moves that carry those plans out.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const CANNON: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
## Feeds the die to the tile on its right.
const RELAY: TileResource = preload("res://Source/Content/Tiles/TileResources/signal_relay.tres")

var grid: TileGrid
var player: Player
var smart: HeuristicPolicy
var build: AutoPilotBuild


func before_each() -> void:
	super()
	grid = TileGrid.new()
	grid.grid_width = 3
	grid.grid_height = 3
	grid.set_cells([] as Array[Vector2i])
	grid.position = Vector2(88, 90)
	add_child_autofree(grid)
	Globals.tile_grid = grid

	player = make_player(3)
	var health: Health = autofree(Health.new())
	health.max_health = 32
	health.health = 32
	player.health = health
	Globals.player = player

	smart = HeuristicPolicy.new(HeuristicPolicy.persona("smart"))
	build = smart._build


func _make(resource: TileResource) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = resource
	return tile


## A tile on the grid and in the tree, its drops going to the grid.
func _place(resource: TileResource, cell: Vector2i) -> Tile:
	var tile: Tile = _make(resource)
	grid.add_child(tile)
	grid._assign_tile_to_grid_pos(tile, cell)
	grid._listen_to_drags(tile)
	return tile


## A tile on offer: in the tree, but not on the grid.
func _offer(resource: TileResource) -> Tile:
	var tile: Tile = _make(resource)
	tile.on_offer = true
	add_child_autofree(tile)
	return tile


func test_only_tiles_that_read_the_grid_are_positional() -> void:
	assert_true(AutoPilotBuild.is_positional(RELAY))
	assert_false(AutoPilotBuild.is_positional(CANNON))


func test_a_relay_is_worth_more_feeding_a_cannon_than_feeding_nothing() -> void:
	var relay: Tile = _place(RELAY, Vector2i(0, 0))
	var alone: float = build.worth_of(AutoPilotBuild.current_layout())
	var cannon: Tile = _place(CANNON, Vector2i(1, 0))
	var fed: float = build.worth_of(AutoPilotBuild.current_layout())
	assert_gt(fed - alone, smart._tile_worth(cannon), "the relay now pays out the cannon's hit too")
	assert_true(is_instance_valid(relay))


func test_a_cannon_goes_where_the_relay_feeds() -> void:
	_place(RELAY, Vector2i(0, 1))
	var spot: Dictionary = build.best_cell_for(_offer(CANNON))
	assert_eq(spot["cell"], Vector2i(1, 1))


func test_a_relay_goes_where_it_feeds_the_cannon() -> void:
	_place(CANNON, Vector2i(2, 2))
	var spot: Dictionary = build.best_cell_for(_offer(RELAY))
	assert_eq(spot["cell"], Vector2i(1, 2))


func test_trying_a_layout_leaves_the_grid_as_it_was() -> void:
	grid.set_open_cells([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	var relay: Tile = _place(RELAY, Vector2i(0, 0))
	var real: Dictionary[Vector2i, Tile] = grid.tile_locations
	var trial: Dictionary[Vector2i, Tile] = {Vector2i(1, 2): relay, Vector2i(2, 2): _offer(CANNON)}
	build.worth_of(trial, [Vector2i(1, 2), Vector2i(2, 2)] as Array[Vector2i])
	assert_same(grid.tile_locations, real)
	assert_eq(grid.tile_locations.size(), 1)
	assert_false(grid.is_grid_pos_valid(Vector2i(2, 2)))
	assert_true(grid.is_cell_locked(Vector2i(2, 2)))


func test_a_grid_slot_opens_the_cell_a_relay_feeds() -> void:
	grid.set_open_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i])
	_place(CANNON, Vector2i(0, 0))
	_place(RELAY, Vector2i(1, 0))
	_place(CANNON, Vector2i(0, 1))
	assert_eq(build.best_sealed_cell([_offer(CANNON)] as Array[Tile]), Vector2i(2, 0))


func test_a_relay_feeding_nothing_is_dragged_beside_a_cannon() -> void:
	var relay: Tile = _place(RELAY, Vector2i(2, 0))
	_place(CANNON, Vector2i(1, 2))
	var best: Dictionary = build.best_rearrangement()
	assert_eq(best.get("tile"), relay)
	assert_eq(best.get("cell"), Vector2i(0, 2))


func test_a_grid_of_tiles_that_ignore_position_is_left_alone() -> void:
	_place(CANNON, Vector2i(0, 0))
	_place(CANNON, Vector2i(2, 2))
	assert_true(build.best_rearrangement().is_empty())


func test_a_relay_adds_little_until_it_feeds_something() -> void:
	var relay: Tile = _place(RELAY, Vector2i(1, 0))
	var cannon: Tile = _place(CANNON, Vector2i(0, 2))
	var idle: float = build.contribution(relay)
	grid.move_tile(cannon, Vector2i(2, 0))
	build.reset()
	assert_gt(build.contribution(relay), idle + 1.0)


func test_a_move_tile_drags_it_across_and_swaps() -> void:
	var relay: Tile = _place(RELAY, Vector2i(0, 0))
	var cannon: Tile = _place(CANNON, Vector2i(1, 0))
	AutoPilotMove.move_tile(cannon, Vector2i(0, 0)).perform()
	assert_eq(grid.find_tile_pos(cannon), Vector2i(0, 0))
	assert_eq(grid.find_tile_pos(relay), Vector2i(1, 0))


func test_a_tile_is_let_go_on_the_cell_it_was_aimed_at() -> void:
	_place(CANNON, Vector2i(0, 0))
	var offered: Tile = _offer(RELAY)
	assert_eq(grid.global_pos_to_grid(AutoPilotMove._drop_point_for(offered, Vector2i(2, 1))), Vector2i(2, 1))
	# Taken, or never aimed: the first free cell.
	assert_eq(grid.global_pos_to_grid(AutoPilotMove._drop_point_for(offered, Vector2i(0, 0))), Vector2i(1, 0))
	assert_eq(grid.global_pos_to_grid(AutoPilotMove._drop_point_for(offered)), Vector2i(1, 0))


func test_a_claim_aimed_by_the_bot_names_its_cell() -> void:
	_place(RELAY, Vector2i(0, 1))
	var claim: AutoPilotMove = smart._aim(AutoPilotMove.claim(_offer(CANNON)), false)
	assert_eq(claim.cell, Vector2i(1, 1))
	assert_eq(claim.describe()["cell"], "1,1")


func test_a_grid_slot_is_worth_more_the_fuller_the_grid() -> void:
	grid.set_open_cells([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	_place(CANNON, Vector2i(0, 0))
	var roomy: float = smart._slot_value()
	_place(CANNON, Vector2i(1, 0))
	assert_gt(smart._slot_value(), roomy)


func test_dice_beyond_what_the_grid_can_use_are_worth_less() -> void:
	var relay: Tile = _place(RELAY, Vector2i(0, 0))
	player.num_of_dice = 1
	var needed: float = smart._die_worth()
	player.num_of_dice = 6
	assert_lt(smart._die_worth(), needed)
	assert_true(is_instance_valid(relay))


func test_a_copy_upgrades_its_twin_on_a_full_grid() -> void:
	grid.set_open_cells([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	_place(RELAY, Vector2i(0, 0))
	_place(CANNON, Vector2i(1, 0))
	var copy: Tile = _offer(CANNON)
	assert_true(AutoPilotMove._has_somewhere_to_go(copy))
	assert_eq(build.best_cell_for(copy)["cell"], Vector2i(1, 0))
	assert_eq(grid.global_pos_to_grid(AutoPilotMove._drop_point_for(copy)), Vector2i(1, 0))


func test_a_copy_of_a_tile_with_no_upgrade_has_nowhere_on_a_full_grid() -> void:
	grid.set_open_cells([Vector2i(0, 0)] as Array[Vector2i])
	var plain: TileResource = TileResource.new()
	_place(plain, Vector2i(0, 0))
	assert_false(AutoPilotMove._has_somewhere_to_go(_offer(plain)))


func test_a_rearrangement_never_swaps_a_tile_onto_its_twin() -> void:
	_place(RELAY, Vector2i(0, 0))
	_place(RELAY, Vector2i(1, 1))
	_place(CANNON, Vector2i(2, 2))
	var best: Dictionary = build.best_rearrangement()
	if not best.is_empty() and grid.tile_locations.has(best["cell"]):
		var there: Tile = grid.tile_locations[best["cell"]]
		assert_eq(there.tile_resource, RELAY, "only a deliberate merge lands on a twin")
		assert_eq(best["tile"].tile_resource, RELAY)
	pass_test("")
