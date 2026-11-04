extends "res://test/helpers/die_fighter_test.gd"
## A die taken from an offer is the player's to play only once it has landed
## in their hand on screen. Players kept letting go of a shop die over a tile,
## or grabbing it mid-flight, and firing that tile (and starting a fight with
## the shopkeeper) before it had arrived.

const SHOP_SCENE: PackedScene = preload("res://Source/Systems/Game/Shop/shop.tscn")
const REWARD_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward_manager.tscn")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

## Well clear of the shop panel, so letting go there buys.
const _TILE_POSITION: Vector2 = Vector2(400, 300)
## Far longer than any flight into the hand takes.
const _ARRIVAL_TIMEOUT: float = 3.0

var shop: Shop
var player: Player
var tile: Tile
var die: Dice


func before_each() -> void:
	super()
	var grid: TileGrid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid
	add_child_autofree(REWARD_MANAGER_SCENE.instantiate())
	Globals.enemy_manager = null
	Globals.state_manager = null

	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	player.money = 100

	tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	add_child_autofree(tile)
	tile.global_position = _TILE_POSITION

	shop = add_child_autofree(SHOP_SCENE.instantiate())
	shop._open_shop()
	die = _shop_die()
	shop._release_from_reveal(die)


func _shop_die() -> Dice:
	for item: Node2D in shop._stock_in_shelf_order():
		if item is Dice:
			return item
	return null


## Lets go of [param held] at [param at], as the player's release would.
func _drop(held: Dice, at: Vector2) -> void:
	held.draggable.state = Draggable.DragState.DRAGGING
	held.draggable._end_drag(at)


func _press_on(held: Dice) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = held.get_global_transform_with_canvas().origin
	held.draggable._on_input_event(get_viewport(), press, 0)


func test_a_shop_die_is_on_offer_until_bought() -> void:
	assert_not_null(die, "the extra shelf holds a die")
	assert_eq(die.delivery, Dice.Delivery.ON_OFFER)
	assert_false(die.is_playable())
	assert_true(die.draggable.can_pick_up(), "but it can be picked up, to buy it")


func test_letting_go_over_a_tile_buys_it_without_firing_the_tile() -> void:
	watch_signals(Events)
	_drop(die, tile.global_position)

	assert_signal_not_emitted(Events, "die_placed_on_tile", "the tile doesn't fire")
	assert_does_not_have(tile.dice_queue.queue, die)
	assert_eq(player.money, 100 - Shop.DICE_PRICE, "it's bought")
	assert_has(player.dice_manager.queue, die, "and heads for the hand")
	assert_eq(die.delivery, Dice.Delivery.ARRIVING)


func test_a_bought_die_is_out_of_reach_until_it_lands_in_the_hand() -> void:
	_drop(die, tile.global_position)
	assert_false(die.draggable.can_pick_up(), "out of reach mid-flight")
	assert_true(die.draggable.dragging_allowed, "without taking over anyone else's lock")

	_press_on(die)
	assert_ne(die.draggable.state, Draggable.DragState.DRAGGING, "a press doesn't pick it up")

	watch_signals(Events)
	_drop(die, tile.global_position)
	assert_signal_not_emitted(Events, "die_placed_on_tile", "a drop by code mid-flight plays nothing")
	assert_has(player.dice_manager.queue, die, "it keeps heading home")

	await wait_for_signal(die.draggable.reached_new_home, _ARRIVAL_TIMEOUT)
	assert_lt(die.global_position.distance_to(die.draggable.home_position), 2.0, "it's in the hand")
	assert_eq(die.delivery, Dice.Delivery.DELIVERED)
	assert_true(die.is_playable())
	assert_true(die.draggable.can_pick_up())


func test_once_it_has_landed_it_plays_like_any_die() -> void:
	_drop(die, _TILE_POSITION + Vector2(0, 200))
	await wait_for_signal(die.draggable.reached_new_home, _ARRIVAL_TIMEOUT)

	_press_on(die)
	assert_eq(die.draggable.state, Draggable.DragState.DRAGGING, "it picks up now")
	watch_signals(Events)
	die.draggable._end_drag(tile.global_position)
	assert_signal_emitted(Events, "die_placed_on_tile", "and the tile takes it")
	assert_has(tile.dice_queue.queue, die)
