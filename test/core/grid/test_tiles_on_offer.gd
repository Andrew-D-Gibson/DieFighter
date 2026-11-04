extends "res://test/helpers/die_fighter_test.gd"
## A tile in the shop or offered as salvage is shown but not the player's: it
## takes no dice until it's installed on the grid.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")


func _tile() -> Tile:
	return autofree(TILE_SCENE.instantiate())


func test_a_tile_on_offer_takes_no_dice() -> void:
	var tile: Tile = _tile()
	tile.on_offer = true
	assert_false(tile.can_accept_dice.enabled, "an unbought tile can't be played for free")


func test_a_tile_taken_off_offer_takes_dice_again() -> void:
	var tile: Tile = _tile()
	tile.on_offer = true
	tile.on_offer = false
	assert_true(tile.can_accept_dice.enabled)


func test_a_tile_starts_off_offer() -> void:
	assert_false(_tile().on_offer, "only the shop and salvage put a tile on offer")
	assert_true(_tile().can_accept_dice.enabled)
