extends "res://test/helpers/die_fighter_test.gd"
## The beaten boss's gate stands aside for its salvage, then slides back to the
## middle of the window once the salvage is taken.

const GATE_SCENE: PackedScene = preload("res://Source/Systems/Game/JumpGate/jump_gate.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const REWARD_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward.tscn")

## Well clear of the offer's window, where a player drops a choice to take it.
const _FAR_AWAY: Vector2 = Vector2(5000, 5000)
## Long enough for the slide's delay and the slide itself.
const _SETTLE_TIME: float = JumpGate._RECENTRE_DELAY + JumpGate._RECENTRE_TIME + 0.2

var _gate: JumpGate
var _rewards: RewardManager


func before_each() -> void:
	super()
	var grid: TileGrid = add_child_autofree(TileGrid.new())
	Globals.tile_grid = grid
	Globals.background_manager = null
	Globals.enemy_manager = null
	_rewards = add_child_autofree(RewardManager.new())
	_gate = add_child_autofree(GATE_SCENE.instantiate())


func _bare_tile() -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	return tile


## A two-tile offer on show at [param x], laid out the way a payout lays it out.
func _offer(x: float) -> Reward:
	var offer: Reward = REWARD_SCENE.instantiate()
	_rewards.add_child(offer)
	offer.global_position = Vector2(x, 40)
	offer.items = [{"tile": "a"}, {"tile": "b"}]
	var choices: Array[Node2D] = [_bare_tile(), _bare_tile()]
	offer._present(choices)
	return offer


func _take_from(offer: Reward) -> void:
	var taken: Tile = offer.rewards[0]
	offer._end_reward(taken.draggable, _FAR_AWAY)


func test_the_gate_slides_to_the_centre_once_the_salvage_is_taken() -> void:
	var offer: Reward = _offer(_gate.rest_position.x)
	_gate.open(false)
	assert_ne(_gate.position.x, _gate.rest_position.x, "stands aside for the offer")

	_take_from(offer)
	await wait_seconds(_SETTLE_TIME)
	assert_eq(_gate.position.x, _gate.rest_position.x)
	assert_true(_gate.is_open(), "still the way out")
	assert_true(_gate.ring.visible and _gate.portal.visible)


func test_the_slide_is_a_tween_not_a_jump() -> void:
	var offer: Reward = _offer(_gate.rest_position.x)
	_gate.open(true)
	var aside_x: float = _gate.position.x
	_take_from(offer)
	await wait_seconds(JumpGate._RECENTRE_DELAY + JumpGate._RECENTRE_TIME / 2.0)
	assert_ne(_gate.position.x, aside_x, "on its way")
	assert_ne(_gate.position.x, _gate.rest_position.x, "not there yet")


func test_the_gate_keeps_clear_of_offers_still_up() -> void:
	var taken: Reward = _offer(_gate.rest_x_range.y)
	var left: Reward = _offer(100)
	_gate.open(true)
	var between_x: float = _gate.position.x
	_take_from(taken)
	await wait_seconds(_SETTLE_TIME)
	assert_ne(_gate.position.x, between_x, "moved off the spot it took between the two")
	assert_eq(_gate.position.x, _gate._clear_rest_x(), "the clearest spot with one offer left")
	assert_ne(_gate.position.x, _gate.rest_position.x, "not the centre: that's under the offer still up")
	assert_gt(_gate.position.x - JumpGate._RING_HALF_WIDTH, left.global_position.x, "clear of it")


func test_a_closed_gate_ignores_picks() -> void:
	var offer: Reward = _offer(_gate.rest_position.x)
	var before: Vector2 = _gate.position
	_take_from(offer)
	await wait_seconds(_SETTLE_TIME)
	assert_false(_gate.is_open())
	assert_eq(_gate.position, before)


func test_nothing_in_the_gate_catches_the_mouse() -> void:
	# The ring sits over the window wherever it ends up; clicks there must
	# still reach whatever the player is clicking.
	_gate.open(true)
	var controls: Array[Node] = _gate.find_children("*", "Control", true, false)
	assert_false(controls.is_empty())
	for control: Control in controls:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, control.name)
	assert_true(_gate.find_children("*", "CollisionObject2D", true, false).is_empty())
