extends "res://test/helpers/die_fighter_test.gd"
## The shop opens in beats: the panel unfolds once the shopkeeper has slid
## aside, then the stock pops onto the shelves one by one. The stock exists
## (and is saveable) from the start; it just can't be seen or bought early.

const SHOP_SCENE: PackedScene = preload("res://Source/Systems/Game/Shop/shop.tscn")
const REWARD_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward_manager.tscn")

var shop: Shop


func before_each() -> void:
	super()
	var grid: TileGrid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid
	add_child_autofree(REWARD_MANAGER_SCENE.instantiate())
	Globals.enemy_manager = null
	Globals.state_manager = null
	shop = add_child_autofree(SHOP_SCENE.instantiate())
	shop._open_shop()


func _stock() -> Array[Node2D]:
	return shop._stock_in_shelf_order()


## The whole opening, with a little to spare.
func _opening_time() -> float:
	return Shop._OPEN_DELAY + Shop._PANEL_OPEN_TIME * 1.5 \
		+ Shop._STOCK_STAGGER * _stock().size() + Shop._STOCK_POP_TIME + 0.3


func test_the_stock_is_on_the_shelves_at_once_but_held_back() -> void:
	assert_eq(_stock().size(), 5, "four tiles and the die")
	assert_false(shop.capture_stock()["tiles"].is_empty(), "saveable from the start")
	for item: Node2D in _stock():
		assert_false(item.visible, "out of sight until it pops in")
		assert_false(item.draggable.dragging_allowed, "and out of reach")
	assert_lt(shop.get_node("Background").scale.y, 0.01, "the panel is still folded")


func test_everything_is_shown_and_buyable_once_it_has_opened() -> void:
	var held: Dictionary[Node, Array] = shop._held_for_reveal.duplicate()
	await wait_seconds(_opening_time())
	assert_eq(shop.get_node("Background").scale, Vector2.ONE)
	for item: Node2D in _stock():
		assert_true(item.visible)
		assert_true(item.draggable.dragging_allowed)
		assert_eq(item.scale, Vector2.ONE, "settled after its pop")
	for item: Node2D in _stock():
		assert_eq(item.draggable.floating_enabled, held[item][1], "floats (or not) as it did before")


func test_the_stock_pops_in_shelf_order() -> void:
	await wait_seconds(Shop._OPEN_DELAY + Shop._PANEL_OPEN_TIME * 1.5 + Shop._STOCK_STAGGER * 0.5)
	var shown: Array[bool] = []
	for item: Node2D in _stock():
		shown.append(item.visible)
	assert_true(shown[0], "the first slot is out")
	assert_false(shown[-1], "the die comes last")


func test_closing_mid_opening_leaves_nothing_held() -> void:
	await wait_seconds(Shop._OPEN_DELAY * 0.5)
	shop._close_shop()
	assert_false(shop.visible)
	assert_true(shop._held_for_reveal.is_empty())
	assert_eq(shop.get_node("Background").scale, Vector2.ONE)
	for item: Node2D in _stock():
		assert_true(item.draggable.dragging_allowed)
