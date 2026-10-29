extends "res://test/helpers/die_fighter_test.gd"
## The rules salvage and the shop share for taking an item: where a tile, a
## Grid Slot or a die can be let go, and what taking each one does.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const GRID_SLOT_SCENE: PackedScene = preload("res://Source/Systems/Game/GridSlot/grid_slot.tscn")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")

## Nowhere near the grid.
const _FAR_AWAY: Vector2 = Vector2(5000, 5000)

var grid: TileGrid
## Every tile on the grid is a copy of this, which has an upgrade.
var upgradeable: TileResource


func before_each() -> void:
	super()
	grid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid
	upgradeable = TileResource.new()
	upgradeable.upgraded_version = TileResource.new()
	upgradeable.upgraded_version.is_upgrade = true


func _tile(resource: TileResource = TileResource.new()) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = resource
	return tile


func _fill_grid() -> void:
	for cell: Vector2i in grid.get_cells():
		grid._assign_tile_to_grid_pos(autofree(_tile(upgradeable)), cell)


func test_a_tile_needs_a_free_cell() -> void:
	var tile: Tile = add_child_autofree(_tile())
	assert_eq(OfferIntake.refusal(tile, _FAR_AWAY), "")
	_fill_grid()
	assert_eq(OfferIntake.refusal(tile, _FAR_AWAY), "GRID FULL")


func test_a_full_grid_still_takes_a_copy_dropped_on_its_twin() -> void:
	_fill_grid()
	var copy: Tile = add_child_autofree(_tile(upgradeable))
	var twin_cell: Vector2i = grid.get_cells()[0]
	var on_twin: Vector2 = grid.grid_to_global_pos(twin_cell)
	assert_eq(OfferIntake.refusal(copy, on_twin), "")
	assert_eq(OfferIntake.refusal(copy, _FAR_AWAY), "GRID FULL", "but not dropped anywhere else")

	OfferIntake.take(copy, on_twin)
	assert_eq(grid.tile_locations[twin_cell].tile_resource, upgradeable.upgraded_version, "the twin upgrades")
	assert_true(copy.is_queued_for_deletion(), "the copy is used up")


func test_a_grid_slot_only_goes_on_a_sealed_cell() -> void:
	var cells: Array[Vector2i] = grid.get_cells()
	var open_cell: Vector2i = cells[0]
	var sealed_cell: Vector2i = cells[1]
	grid.set_open_cells([open_cell])
	var slot: GridSlot = add_child_autofree(GRID_SLOT_SCENE.instantiate())

	assert_ne(OfferIntake.refusal(slot, _FAR_AWAY), "")
	assert_ne(OfferIntake.refusal(slot, grid.grid_to_global_pos(open_cell)), "")
	assert_eq(OfferIntake.refusal(slot, grid.grid_to_global_pos(sealed_cell)), "")


func test_taking_a_grid_slot_opens_the_cell_under_it() -> void:
	var cells: Array[Vector2i] = grid.get_cells()
	var sealed_cell: Vector2i = cells[1]
	grid.set_open_cells([cells[0]])
	var slot: GridSlot = add_child_autofree(GRID_SLOT_SCENE.instantiate())

	OfferIntake.take(slot, grid.grid_to_global_pos(sealed_cell))
	assert_false(grid.is_cell_locked(sealed_cell))
	assert_true(grid.is_grid_pos_valid(sealed_cell), "a tile can sit there now")
	assert_eq(slot.get_parent(), grid, "the grid carries it in")


func test_taking_a_die_adds_it_to_the_hand() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	var owned: int = player.num_of_dice
	var die: Dice = add_child_autofree(DICE_SCENE.instantiate())

	assert_eq(OfferIntake.refusal(die, _FAR_AWAY), "", "a die always has room")
	OfferIntake.take(die, _FAR_AWAY)
	assert_eq(die.get_parent(), player)
	assert_has(player.dice_manager.queue, die)
	assert_eq(player.num_of_dice, owned + 1)
