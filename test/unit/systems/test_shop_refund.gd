extends "res://test/helpers/die_fighter_test.gd"
## Turning on a trader wins back what was spent with it: every credit paid at
## a shop (stock and rerolls) or a repair dock (repairs) is banked on the ship
## running it, and its wreck pays the lot back on top of its usual reward.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const SHOP_SCENE: PackedScene = preload("res://Source/Systems/Game/Shop/shop.tscn")
const STATION_SCENE: PackedScene = preload("res://Source/Systems/Game/RepairStation/repair_station.tscn")
const REWARD_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/RewardManager/reward_manager.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const MERCHANT: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/shop.tres")
const SHOP_DEFAULT: ScenarioShipState = preload("res://Source/Content/ScenarioResources/Scenarios/Shop/shop_ship_default.tres")
const DOCK_DEFAULT: ScenarioShipState = preload("res://Source/Content/ScenarioResources/Scenarios/RepairStation/repair_dock_default.tres")

var player: Player
var keeper: Enemy
var loot: RewardResource


## A roster to look the keeper up in, with no enemy path to lay a formation
## along: the panels' formation claims are beside the point here.
class RosterOnly extends EnemyManager:
	func reserve_formation_space(_key: StringName, _min_x: float, _max_x: float) -> void:
		pass

	func clear_formation_space(_key: StringName) -> void:
		pass


func before_each() -> void:
	super()
	var grid: TileGrid = TileGrid.new()
	add_child_autofree(grid)
	Globals.tile_grid = grid
	Globals.state_manager = null
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.money = 200
	Globals.player = player

	loot = RewardResource.new()
	loot.min_money = 36
	loot.max_money = 48
	loot.num_of_rewards = 4

	Globals.enemy_manager = autofree(RosterOnly.new())
	keeper = ENEMY_SCENE.instantiate()
	keeper.enemy_resource = MERCHANT
	keeper.scenario_state = SHOP_DEFAULT
	keeper.reward_resource = loot
	keeper.spawn_index = 0
	add_child_autofree(keeper)
	Globals.enemy_manager.enemies = [keeper] as Array[Enemy]


# ── The wreck's reward ─────────────────────────────────────────────────────────

func test_a_ship_owed_nothing_pays_its_authored_reward() -> void:
	assert_same(keeper.wreck_reward(), loot)


func test_the_wreck_pays_back_every_credit_paid_to_it() -> void:
	keeper.credits_paid = 57
	var reward: RewardResource = keeper.wreck_reward()
	assert_eq(reward.min_money, 36 + 57)
	assert_eq(reward.max_money, 48 + 57)
	assert_eq(reward.num_of_rewards, 4, "the usual loot still comes with it")
	assert_eq(loot.min_money, 36, "the authored reward, shared by every visit, is untouched")
	assert_eq(loot.max_money, 48)


func test_a_ship_with_no_loot_still_pays_back_what_it_took() -> void:
	keeper.reward_resource = null
	assert_null(keeper.wreck_reward())
	keeper.credits_paid = 20
	var reward: RewardResource = keeper.wreck_reward()
	assert_eq(reward.min_money, 20)
	assert_eq(reward.max_money, 20)
	assert_eq(reward.num_of_rewards, 0)


func test_destroying_the_keeper_drops_the_refund_with_its_loot() -> void:
	keeper.credits_paid = 40
	watch_signals(Events)
	keeper.health.change_health(-keeper.health.health)
	await wait_for_signal(Events.spawn_reward, 3.0)
	assert_signal_emitted(Events, "spawn_reward")
	var reward: RewardResource = get_signal_parameters(Events, "spawn_reward")[1]
	assert_eq(reward.min_money, 36 + 40)
	assert_eq(reward.max_money, 48 + 40)


func test_the_refund_is_named_apart_from_the_loot() -> void:
	assert_eq(loot.refund, 0, "an authored reward owes nothing back")
	keeper.credits_paid = 25
	assert_eq(keeper.wreck_reward().refund, 25)
	assert_eq(loot.refund, 0, "the shared resource is untouched")


## The payout calls the refund out on its own line, so the player learns that
## turning on a trader wins the spend back. Money alone still gets the line,
## though the offer itself is gone at once.
func test_the_payout_calls_out_the_refund() -> void:
	var manager: RewardManager = add_child_autofree(REWARD_MANAGER_SCENE.instantiate())
	keeper.reward_resource = null
	keeper.credits_paid = 18
	manager._spawn_reward(Vector2(80, 60), keeper.wreck_reward())
	var lines: Array[String] = _callouts(manager)
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], tr(&"CALLOUT_REFUND").format({"amount": 18}))
	assert_string_contains(lines[0], "18")


func test_loot_alone_calls_out_no_refund() -> void:
	var manager: RewardManager = add_child_autofree(REWARD_MANAGER_SCENE.instantiate())
	loot.num_of_rewards = 0
	manager._spawn_reward(Vector2(80, 60), keeper.wreck_reward())
	assert_eq(_callouts(manager).size(), 0)


func _callouts(parent: Node) -> Array[String]:
	var lines: Array[String] = []
	for child: Node in parent.get_children():
		if child is DamageNumber:
			lines.append((child as DamageNumber)._label.text)
	return lines


## The penalty for it is unchanged: attacking the trader turns it hostile and
## shuts the counter.
func test_attacking_a_trader_still_turns_it_against_the_player() -> void:
	for start: ScenarioShipState in [SHOP_DEFAULT, DOCK_DEFAULT]:
		var angry: ScenarioShipState = start.handle_scenario_event(
			ScenarioManager.ScenarioEvent.PLAYER_ATTACKED_CIVILIAN)
		assert_ne(angry, start)
		assert_eq(angry.attitude, Enemy.Attitude.AGGRESSIVE)
		assert_eq(angry.faction, ScenarioManager.Faction.CIVILIAN)
		var closes: bool = false
		for effect: EffectData in angry.effects_on_enter.effects:
			closes = closes or (effect.category == EffectEnums.Category.SCENARIO_CONTROL and effect.subtype in [
				EffectEnums.ScenarioControlSubtype.CLOSE_SHOP,
				EffectEnums.ScenarioControlSubtype.CLOSE_REPAIR_STATION])
		assert_true(closes, "its counter shuts")


# ── Shops ──────────────────────────────────────────────────────────────────────

func _open_shop() -> Shop:
	add_child_autofree(REWARD_MANAGER_SCENE.instantiate())
	var shop: Shop = add_child_autofree(SHOP_SCENE.instantiate())
	shop._open_shop(keeper)
	await wait_seconds(Shop._OPEN_DELAY + Shop._PANEL_OPEN_TIME * 1.5
		+ Shop._STOCK_STAGGER * 5 + Shop._STOCK_POP_TIME + 0.3)
	return shop


func test_purchases_and_rerolls_are_banked_on_the_shopkeeper() -> void:
	var shop: Shop = await _open_shop()
	assert_true(shop.reroll())
	assert_eq(keeper.credits_paid, 8)
	await wait_seconds(Shop._STOCK_OUT_STAGGER * 5 + Shop._STOCK_OUT_TIME
		+ Shop._STOCK_STAGGER * 5 + Shop._STOCK_POP_TIME + 0.3)

	var die: Dice = null
	for item: Node2D in shop._stock_in_shelf_order():
		if item is Dice:
			die = item
	assert_not_null(die, "an empty grid has no sealed cell, so the extra shelf holds a die")
	var before: int = player.money
	die.draggable.drag_ended.emit(die.draggable, Vector2(5000, 5000))
	assert_eq(player.money, before - Shop.DICE_PRICE, "bought")
	assert_eq(keeper.credits_paid, 8 + Shop.DICE_PRICE)


func test_a_continue_keeps_the_shopkeeper_on_the_books() -> void:
	var shop: Shop = await _open_shop()
	shop.reroll()
	var saved: Dictionary = shop.capture_stock()
	assert_eq(saved["keeper"], 0)

	var state: GameStateManager = autofree(GameStateManager.new())
	state._restore = {"shop": saved}
	Globals.state_manager = state
	# A restored keeper doesn't replay the arrival effect that names it.
	shop._open_shop()
	assert_same(shop.keeper, keeper)


# ── Repair docks ───────────────────────────────────────────────────────────────

func _open_station() -> RepairStation:
	var health: Health = autofree(Health.new())
	health.max_health = 80
	health.health = 10
	player.health = health
	var station: RepairStation = add_child_autofree(STATION_SCENE.instantiate())
	station._open_station(keeper)
	return station


func test_repairs_are_banked_on_the_dock() -> void:
	var station: RepairStation = _open_station()
	assert_true(station.repair())
	assert_true(station.repair())
	assert_eq(keeper.credits_paid, 10 + 15)


## Open question for the design: should a sale count against the tally? For
## now it doesn't; the tally is what the player paid, not their net.
func test_selling_a_tile_leaves_the_tally_alone() -> void:
	var station: RepairStation = _open_station()
	station.repair()
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
		var tile: Tile = autofree(TILE_SCENE.instantiate())
		tile.tile_resource = TileResource.new()
		Globals.tile_grid._assign_tile_to_grid_pos(tile, cell)
	assert_true(station.sell(Globals.tile_grid.tile_locations[Vector2i(0, 0)]))
	assert_eq(keeper.credits_paid, 10)


func test_a_continue_keeps_the_dock_on_the_books() -> void:
	var station: RepairStation = _open_station()
	station.repair()
	var saved: Dictionary = station.capture_state()
	assert_eq(saved["keeper"], 0)

	var state: GameStateManager = autofree(GameStateManager.new())
	state._restore = {"repair_station": saved}
	Globals.state_manager = state
	station._close_station()
	station._reopen_saved_station()
	assert_same(station.keeper, keeper)


# ── Saving the ship ────────────────────────────────────────────────────────────

func test_a_saved_ship_still_owes_what_it_was_paid() -> void:
	keeper.credits_paid = 33
	var saved: Dictionary = keeper.capture_state()
	keeper.credits_paid = 0
	keeper.restore_state(saved, SHOP_DEFAULT)
	assert_eq(keeper.credits_paid, 33)


func test_a_save_from_before_the_tally_owes_nothing() -> void:
	var saved: Dictionary = keeper.capture_state()
	saved.erase("credits_paid")
	keeper.credits_paid = 12
	keeper.restore_state(saved, SHOP_DEFAULT)
	assert_eq(keeper.credits_paid, 0)
