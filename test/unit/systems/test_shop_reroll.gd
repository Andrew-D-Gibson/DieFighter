extends "res://test/helpers/die_fighter_test.gd"
## The shop's reroll: credits for a fresh set of tiles on the four tile
## shelves, at a price that climbs with each reroll at the same shop.

const SHOP_SCENE: PackedScene = preload("res://Source/Systems/Game/Shop/shop.tscn")
const REWARD_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward_manager.tscn")

var shop: Shop
var player: Player


func before_each() -> void:
	super()
	var grid: TileGrid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid
	add_child_autofree(REWARD_MANAGER_SCENE.instantiate())
	Globals.enemy_manager = null
	Globals.state_manager = null
	player = make_player()
	player.money = 100
	Globals.player = player
	shop = add_child_autofree(SHOP_SCENE.instantiate())
	shop._open_shop()


func _opening_time() -> float:
	return Shop._OPEN_DELAY + Shop._PANEL_OPEN_TIME * 1.5 \
		+ Shop._STOCK_STAGGER * 5 + Shop._STOCK_POP_TIME + 0.3


## Old stock off, new stock on, with a little to spare.
func _reroll_time() -> float:
	return Shop._STOCK_OUT_STAGGER * 4 + Shop._STOCK_OUT_TIME \
		+ Shop._STOCK_STAGGER * 4 + Shop._STOCK_POP_TIME + 0.3


func _shelf_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for item: Node2D in shop._stock_in_shelf_order():
		if item is Tile:
			tiles.append(item)
	return tiles


func _opened() -> void:
	await wait_seconds(_opening_time())


func test_a_reroll_charges_and_each_costs_more() -> void:
	await _opened()
	assert_eq(shop.reroll_cost(), 8)
	assert_true(shop.reroll())
	assert_eq(player.money, 92)
	assert_eq(shop.reroll_cost(), 12)
	await wait_seconds(_reroll_time())
	assert_true(shop.reroll())
	assert_eq(player.money, 80)
	assert_eq(shop.reroll_cost(), 16)


func test_a_reroll_swaps_the_tiles_for_new_ones() -> void:
	await _opened()
	var before: Array[Tile] = _shelf_tiles()
	var old_resources: Array[TileResource] = []
	for tile: Tile in before:
		old_resources.append(tile.tile_resource)
	var die: Node = null
	for item: Node2D in shop._stock_in_shelf_order():
		if item is Dice:
			die = item

	shop.reroll()
	for tile: Tile in before:
		assert_false(tile.draggable.dragging_allowed, "the old stock can't be bought on its way out")
	await wait_seconds(_reroll_time())

	var after: Array[Tile] = _shelf_tiles()
	assert_eq(after.size(), 4, "every tile shelf restocked")
	for tile: Tile in after:
		assert_false(before.has(tile))
		assert_false(old_resources.has(tile.tile_resource), "none of the tiles just cleared come straight back")
		assert_true(tile.visible)
		assert_true(tile.draggable.dragging_allowed, "the new stock is for sale")
		assert_eq(tile.scale, Vector2.ONE)
		assert_true(shop.price_of(tile) > 0)
	for tile: Tile in before:
		assert_false(is_instance_valid(tile) and tile.is_inside_tree(), "the old stock is gone")
	assert_true(is_instance_valid(die) and shop.item_to_shop_index.has(die), "the die stays on its shelf")


func test_a_sold_shelf_is_restocked_too() -> void:
	await _opened()
	var sold: Tile = _shelf_tiles()[0]
	var shelf: int = shop.item_to_shop_index[sold]
	shop._forget(sold)
	shop.prices[shelf].visible = false
	sold.queue_free()

	shop.reroll()
	await wait_seconds(_reroll_time())
	assert_eq(_shelf_tiles().size(), 4)
	assert_true(shop.prices[shelf].visible)


func test_a_reroll_the_player_cant_afford_is_refused() -> void:
	await _opened()
	player.money = 7
	var before: Array[Tile] = _shelf_tiles()
	assert_false(shop.reroll())
	assert_eq(player.money, 7, "nothing paid")
	assert_eq(_shelf_tiles(), before)
	assert_true(shop.reroll_button.disabled, "the button greys out")


func test_no_reroll_while_the_shop_is_opening_or_restocking() -> void:
	assert_false(shop.reroll(), "still opening")
	assert_true(shop.reroll_button.disabled)
	await _opened()
	assert_false(shop.reroll_button.disabled)
	assert_true(shop.reroll())
	assert_true(shop.reroll_button.disabled, "busy while the shelves swap")
	assert_false(shop.reroll(), "one at a time")
	assert_eq(player.money, 92)
	await wait_seconds(_reroll_time())
	assert_false(shop.reroll_button.disabled)


func test_closing_mid_reroll_sells_nothing() -> void:
	await _opened()
	shop.reroll()
	await wait_seconds(Shop._STOCK_OUT_TIME)
	shop._close_shop()
	assert_false(shop.is_restocking())
	for item: Node2D in shop._stock_in_shelf_order():
		assert_false(item.draggable.dragging_allowed)
	await wait_seconds(1.0)
	assert_false(shop.visible)


func test_a_continue_keeps_the_reroll_price() -> void:
	await _opened()
	shop.reroll()
	await wait_seconds(_reroll_time())
	shop.reroll()
	await wait_seconds(_reroll_time())
	var saved: Dictionary = shop.capture_stock()
	assert_eq(saved["rerolls"], 2)
	assert_eq(saved["tiles"].size(), 4)

	var state: GameStateManager = autofree(GameStateManager.new())
	state._restore = {"shop": saved}
	Globals.state_manager = state
	shop._open_shop()
	assert_eq(shop.rerolls_bought, 2)
	assert_eq(shop.reroll_cost(), 16)


func test_a_fresh_shop_starts_at_the_base_price() -> void:
	shop.rerolls_bought = 3
	shop._open_shop()
	assert_eq(shop.reroll_cost(), 8)
