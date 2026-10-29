extends "res://test/helpers/die_fighter_test.gd"
## The AutoPilot and the shop's reroll: the move goes through the shop's own
## handler, and how the heuristic bot weighs one.

const SHOP_SCENE: PackedScene = preload("res://Source/Systems/Game/Shop/shop.tscn")
const REWARD_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward_manager.tscn")
const STATION_SCENE: PackedScene = preload("res://Source/Systems/Game/RepairStation/repair_station.tscn")

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


func _opened() -> void:
	await wait_seconds(Shop._OPEN_DELAY + Shop._PANEL_OPEN_TIME * 1.5
		+ Shop._STOCK_STAGGER * 5 + Shop._STOCK_POP_TIME + 0.3)


func test_a_reroll_move_presses_the_shops_button() -> void:
	await _opened()
	var move: AutoPilotMove = AutoPilotMove.reroll(shop.reroll_cost())
	assert_eq(move.describe(), {"move": "reroll", "price": 8})
	move.perform()
	assert_eq(player.money, 92)
	assert_eq(shop.rerolls_bought, 1)
	assert_true(shop.is_restocking())


func test_the_smart_bot_never_rerolls_into_its_reserve() -> void:
	await _opened()
	var bot: HeuristicPolicy = HeuristicPolicy.new(HeuristicPolicy.persona("smart"))
	player.money = HeuristicPolicy._REROLL_RESERVE + 7
	assert_eq(bot._reroll_gain(8), -INF, "paying 8 would leave less than the reserve")


func test_the_reserve_grows_with_the_repairs_it_would_want() -> void:
	var station: RepairStation = add_child_autofree(STATION_SCENE.instantiate())
	Globals.repair_station = station
	var health: Health = autofree(Health.new())
	health.max_health = 80
	health.health = 80
	player.health = health
	var bot: HeuristicPolicy = HeuristicPolicy.new(HeuristicPolicy.persona("smart"))
	assert_eq(bot._repair_fund(), 0, "a full hull needs nothing kept back")
	health.health = 30
	# Smart repairs up to about 0.77 of 80 (62): 32 missing, three repairs of
	# 15 at 10, 15 and 20.
	assert_eq(bot._repair_fund(), 45)


func test_no_buyable_tile_in_the_pool_means_no_gain() -> void:
	var nets: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.0, 0.45)]
	assert_eq(HeuristicPolicy.expected_best_of(nets, 1.45, 4), 0.0)


func test_the_expected_best_is_the_chance_of_drawing_it_times_its_worth() -> void:
	# One tile in ten worth 3 points: a shelf of 4 holds it 1 - 0.9^4 of the time.
	var nets: Array[Vector2] = [Vector2(3.0, 1.0)]
	for i: int in 9:
		nets.append(Vector2(0.0, 1.0))
	assert_almost_eq(HeuristicPolicy.expected_best_of(nets, 10.0, 4), 3.0 * (1.0 - pow(0.9, 4)), 0.0001)


func test_the_expected_best_takes_the_better_of_two_buys() -> void:
	# Half the weight worth 1, half worth 2: two draws give 2 unless both are 1.
	var nets: Array[Vector2] = [Vector2(2.0, 1.0), Vector2(1.0, 1.0)]
	assert_almost_eq(HeuristicPolicy.expected_best_of(nets, 2.0, 2), 1.0 * 0.25 + 2.0 * 0.75, 0.0001)


func test_rarer_tiles_count_for_less() -> void:
	var common: Array[Vector2] = [Vector2(3.0, 1.0), Vector2(0.0, 1.0)]
	var rare: Array[Vector2] = [Vector2(3.0, 0.18), Vector2(0.0, 1.0)]
	assert_gt(HeuristicPolicy.expected_best_of(common, 2.0, 4), HeuristicPolicy.expected_best_of(rare, 1.18, 4))
