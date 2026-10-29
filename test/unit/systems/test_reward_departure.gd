extends "res://test/helpers/die_fighter_test.gd"
## How a salvage offer leaves the screen: the choices left over once one is
## taken pop out, and an offer the player jumps away from falls behind with
## the departing ships, rather than either snapping out of existence.

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
	Globals.background_manager = null


func _bare_tile() -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	return tile


## An offer of two tiles on show, laid out the way a ship's payout lays it out.
func _offer() -> Reward:
	var offer: Reward = add_child_autofree(REWARD_SCENE.instantiate())
	offer.position = Vector2(240, 40)
	offer.items = [{"tile": "a"}, {"tile": "b"}]
	var choices: Array[Node2D] = [_bare_tile(), _bare_tile()]
	offer._present(choices)
	return offer


func test_taking_a_choice_clears_the_rest_away_rather_than_at_once() -> void:
	var offer: Reward = _offer()
	var taken: Tile = offer.rewards[0]
	var left: Tile = offer.rewards[1]
	offer._end_reward(taken.draggable, _FAR_AWAY)
	assert_eq(taken.get_parent(), grid, "the choice went to the grid")
	assert_false(offer.is_queued_for_deletion(), "the rest is still on its way out")
	assert_false(offer.can_take(), "the rest can't be taken as well")
	assert_true(offer.items.is_empty(), "a spent offer isn't saved")
	assert_false(left.draggable.dragging_allowed)
	await wait_seconds(0.6)
	assert_false(is_instance_valid(offer), "gone once the pops have played")


func test_jumping_away_leaves_the_offer_behind() -> void:
	var offer: Reward = _offer()
	var start_y: float = offer.global_position.y
	offer._dismiss()
	assert_false(offer.can_take())
	assert_true(offer.items.is_empty(), "an offer left behind isn't saved")
	await wait_seconds(0.5)
	assert_gt(offer.global_position.y, start_y, "falls down the screen with the ships")
	assert_lt(offer.scale.x, 1.0, "shrinks into the distance")
	assert_lt(offer.modulate.a, 1.0, "fades")
	for choice: Node2D in offer.rewards:
		assert_eq(choice.get_parent(), offer, "carried along, not left at its spot")


func test_an_offer_left_behind_is_freed_once_its_gone() -> void:
	var offer: Reward = _offer()
	offer._dismiss()
	await wait_seconds(Reward._LEFT_BEHIND_TIME + 0.3)
	assert_false(is_instance_valid(offer))


func test_an_offer_still_on_its_way_just_goes() -> void:
	var offer: Reward = add_child_autofree(REWARD_SCENE.instantiate())
	offer.items = [{"dice": true}]
	offer._dismiss()
	assert_true(offer.is_queued_for_deletion(), "nothing on screen to animate")
