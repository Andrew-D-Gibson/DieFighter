extends "res://test/helpers/die_fighter_test.gd"
## The repair station: buying hull at a rising price, selling tiles off the
## grid, what it refuses, and where a sector puts it.

const STATION_SCENE: PackedScene = preload("res://Source/Systems/Game/RepairStation/repair_station.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const ENGINE_CHARGER: TileResource = preload("res://Source/Content/Tiles/MapTileResources/engine_charger.tres")

const _FAR_AWAY: Vector2 = Vector2(5000, 5000)

var station: RepairStation
var grid: TileGrid
var player: Player


func before_each() -> void:
	super()
	grid = TileGrid.new()
	# Where they sit in the game, so the SELL slot is well off the grid.
	grid.position = Vector2(88, 90)
	add_child_autofree(grid)
	Globals.tile_grid = grid

	player = make_player()
	var health: Health = autofree(Health.new())
	health.max_health = 80
	health.health = 50
	player.health = health
	Globals.player = player

	station = STATION_SCENE.instantiate()
	station.position = Vector2(122, 43)
	add_child_autofree(station)


func _tile(rarity: TileResource.Rarity = TileResource.Rarity.COMMON) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = TileResource.new()
	tile.tile_resource.rarity = rarity
	return tile


func _place(tile: Tile, cell: Vector2i) -> Tile:
	grid._assign_tile_to_grid_pos(tile, cell)
	return tile


# ── Repairs ────────────────────────────────────────────────────────────────────

func test_a_repair_heals_and_charges() -> void:
	player.money = 50
	assert_true(station.repair())
	assert_eq(player.health.health, 65)
	assert_eq(player.money, 40)
	assert_eq(station.repairs_bought, 1)


func test_each_repair_costs_more_than_the_last() -> void:
	player.health.health = 2
	player.money = 100
	var costs: Array[int] = []
	for i: int in 3:
		costs.append(station.repair_cost())
		assert_true(station.repair())
	assert_eq(costs, [10, 15, 20] as Array[int])
	assert_eq(player.money, 100 - 45)
	assert_eq(player.health.health, 47)


func test_a_repair_never_heals_past_max() -> void:
	player.health.health = 77
	player.money = 50
	assert_eq(station.repair_amount(), 3)
	assert_true(station.repair())
	assert_eq(player.health.health, 80)
	assert_eq(player.money, 40, "a part repair still costs the full price")


func test_a_full_hull_is_refused() -> void:
	player.health.health = 80
	player.money = 50
	watch_signals(Events)
	assert_false(station.repair_refusal().is_empty())
	assert_false(station.repair())
	assert_eq(player.money, 50)
	assert_eq(station.repairs_bought, 0)
	assert_signal_emitted(Events, "error_text_popup")


func test_a_repair_the_player_cant_afford_is_refused() -> void:
	player.money = 9
	assert_false(station.repair())
	assert_eq(player.money, 9)
	assert_eq(player.health.health, 50)


func test_the_button_greys_out_when_a_repair_cant_be_had() -> void:
	player.money = 50
	station._refresh()
	assert_false(station.repair_button.disabled)
	player.health.health = 80
	station._refresh()
	assert_true(station.repair_button.disabled, "full hull")
	player.health.health = 10
	player.money = 0
	station._refresh()
	assert_true(station.repair_button.disabled, "can't afford")


# ── Selling ────────────────────────────────────────────────────────────────────

func test_sale_prices_are_half_the_average_shop_price() -> void:
	var common := TileResource.new()
	var uncommon := TileResource.new()
	uncommon.rarity = TileResource.Rarity.UNCOMMON
	var rare := TileResource.new()
	rare.rarity = TileResource.Rarity.RARE
	assert_eq(station.sell_price(common), 7)
	assert_eq(station.sell_price(uncommon), 10)
	assert_eq(station.sell_price(rare), 15)


func test_selling_pays_and_frees_the_cell() -> void:
	_place(_tile(), Vector2i(0, 0))
	var sold: Tile = _place(_tile(TileResource.Rarity.RARE), Vector2i(1, 0))
	player.money = 3
	assert_true(station.sell(sold))
	assert_eq(player.money, 18)
	assert_true(grid.is_grid_pos_open(Vector2i(1, 0)))
	assert_true(sold.is_queued_for_deletion())


func test_several_tiles_can_be_sold() -> void:
	var first: Tile = _place(_tile(), Vector2i(0, 0))
	var second: Tile = _place(_tile(TileResource.Rarity.UNCOMMON), Vector2i(1, 0))
	_place(_tile(), Vector2i(2, 0))
	assert_true(station.sell(first))
	assert_true(station.sell(second))
	assert_eq(player.money, 17)
	assert_eq(grid.tile_locations.size(), 1)


func test_the_last_tile_cant_be_sold() -> void:
	var only: Tile = _place(_tile(), Vector2i(0, 0))
	assert_false(station.sale_refusal(only).is_empty())
	assert_false(station.sell(only))
	assert_eq(player.money, 0)
	assert_eq(grid.tile_locations.size(), 1)


func test_the_engine_charger_is_never_for_sale() -> void:
	_place(_tile(), Vector2i(0, 0))
	var charger: Tile = autofree(TILE_SCENE.instantiate())
	charger.tile_resource = ENGINE_CHARGER
	_place(charger, Vector2i(1, 0))
	assert_true(ENGINE_CHARGER in station.unsellable_tiles)
	assert_false(station.sell(charger))
	assert_eq(player.money, 0)


func test_a_tile_that_cant_be_dragged_isnt_for_sale() -> void:
	_place(_tile(), Vector2i(0, 0))
	var fixed: Tile = _place(_tile(), Vector2i(1, 0))
	fixed.tile_resource.dragging_allowed = false
	assert_false(station.sell(fixed))


func test_a_tile_off_the_grid_isnt_for_sale() -> void:
	_place(_tile(), Vector2i(0, 0))
	_place(_tile(), Vector2i(1, 0))
	assert_false(station.sell(_tile()), "shop stock or salvage isn't the player's")


func test_dropping_a_tile_on_the_slot_sells_it() -> void:
	_place(_tile(), Vector2i(0, 0))
	var sold: Tile = _place(_tile(), Vector2i(1, 0))
	station._open_station()
	assert_true(station.is_in_sell_zone(station.sell_zone_centre()))
	grid._drop_tile_on_grid_pos(sold.draggable, station.sell_zone_centre())
	assert_eq(player.money, 7)
	assert_true(grid.is_grid_pos_open(Vector2i(1, 0)))


func test_dropping_a_tile_anywhere_else_keeps_it() -> void:
	_place(_tile(), Vector2i(0, 0))
	var kept: Tile = _place(_tile(), Vector2i(1, 0))
	station._open_station()
	grid._drop_tile_on_grid_pos(kept.draggable, _FAR_AWAY)
	assert_eq(player.money, 0)
	assert_eq(grid.find_tile_pos(kept), Vector2i(1, 0))


func test_a_closed_station_buys_nothing() -> void:
	_place(_tile(), Vector2i(0, 0))
	var kept: Tile = _place(_tile(), Vector2i(1, 0))
	station._open_station()
	station._close_station()
	grid._drop_tile_on_grid_pos(kept.draggable, station.sell_zone_centre())
	assert_eq(player.money, 0)
	assert_eq(grid.find_tile_pos(kept), Vector2i(1, 0))


func test_the_station_fades_away_when_the_player_dies() -> void:
	# The death sequence wants the whole screen.
	_place(_tile(), Vector2i(0, 0))
	var kept: Tile = _place(_tile(), Vector2i(1, 0))
	station._open_station()
	# Called directly: emitting player_destroyed would also reach SaveManager,
	# which deletes the real save.
	station._fade_out_for_death()
	await wait_seconds(Utils.PANEL_FADE_TIME + 0.1)
	assert_false(station.visible)
	grid._drop_tile_on_grid_pos(kept.draggable, station.sell_zone_centre())
	assert_eq(grid.find_tile_pos(kept), Vector2i(1, 0), "it stops buying")

	station._open_station()
	assert_eq(station.modulate.a, 1.0, "it comes back opaque next time")


func test_lifting_a_tile_shows_what_it_would_fetch() -> void:
	_place(_tile(), Vector2i(0, 0))
	var lifted: Tile = _place(_tile(TileResource.Rarity.UNCOMMON), Vector2i(1, 0))
	grid._listen_to_drags(lifted)
	station._open_station()
	lifted.draggable.drag_started.emit()
	assert_true(station.sell_price_tag.visible)
	assert_eq(station.sell_price_tag.get_child(0).text, "+10")
	lifted.draggable.drag_ended.emit(lifted.draggable, grid.grid_to_global_pos(Vector2i(1, 0)))
	assert_false(station.sell_price_tag.visible, "back to the prompt once it's put down")
	assert_eq(player.money, 0)


func test_lifting_the_last_tile_says_why_it_wont_sell() -> void:
	var only: Tile = _place(_tile(), Vector2i(0, 0))
	grid._listen_to_drags(only)
	station._open_station()
	only.draggable.drag_started.emit()
	assert_false(station.sell_price_tag.visible)
	assert_eq(station.sell_hint.text, station.sale_refusal(only))


# ── Saving ─────────────────────────────────────────────────────────────────────

func test_a_continue_keeps_the_repair_price() -> void:
	player.money = 100
	station.repair()
	station.repair()
	var saved: Dictionary = station.capture_state()
	assert_eq(saved, {"repairs": 2})

	var state: GameStateManager = autofree(GameStateManager.new())
	state._restore = {"repair_station": saved}
	Globals.state_manager = state
	station._close_station()
	station._reopen_saved_station()
	assert_true(station.visible)
	assert_eq(station.repairs_bought, 2)
	assert_eq(station.repair_cost(), 20)


func test_a_fresh_visit_starts_at_the_base_price() -> void:
	station.repairs_bought = 3
	station._open_station()
	assert_eq(station.repair_cost(), 10)


# ── Shop prices it's built on ──────────────────────────────────────────────────

func test_base_price_is_the_middle_of_the_shelf_range() -> void:
	assert_eq(Shop.base_price(TileResource.Rarity.COMMON), 15)
	assert_eq(Shop.base_price(TileResource.Rarity.UNCOMMON), 20)
	assert_eq(Shop.base_price(TileResource.Rarity.RARE), 30)


# ── Where a sector puts it ─────────────────────────────────────────────────────

## A sector shaped like the game's: two shops, combats and events, the arrival
## at [param arrival], and the gate last.
func _sector(arrival: int, combat: ScenarioResource, shop: ScenarioResource,
		start: ScenarioResource, gate: ScenarioResource) -> Array[ScenarioResource]:
	var scenarios: Array[ScenarioResource] = []
	for i: int in 13:
		scenarios.append(shop if i % 5 == 0 else combat)
	scenarios.insert(arrival, start)
	scenarios.append(gate)
	return scenarios


func test_stations_replace_ordinary_stops_beyond_a_jump() -> void:
	var combat := ScenarioResource.new()
	var shop := ScenarioResource.new()
	var start := ScenarioResource.new()
	var gate := ScenarioResource.new()
	var station_scenario := ScenarioResource.new()
	var replaceable: Array[ScenarioResource] = [combat]
	for placement_seed: int in 40:
		var scenarios: Array[ScenarioResource] = _sector(2, combat, shop, start, gate)
		GameStateManager.place_repair_stations(
			scenarios, 2, replaceable, station_scenario, Vector2i(1, 2), placement_seed)
		var placed: Array[int] = []
		for index: int in scenarios.size():
			if scenarios[index] == station_scenario:
				placed.append(index)
		assert_between(placed.size(), 1, 2)
		for index: int in placed:
			assert_gt(index, 2 + 6, "out of the first jump's reach")
			assert_lt(index, scenarios.size() - 1, "never the gate")
		assert_eq(scenarios.count(shop), 3, "shops are kept")
		assert_eq(scenarios.back(), gate)
		assert_eq(scenarios[2], start)


func test_placement_is_repeatable_from_its_seed() -> void:
	var combat := ScenarioResource.new()
	var station_scenario := ScenarioResource.new()
	var replaceable: Array[ScenarioResource] = [combat]
	var first: Array[ScenarioResource] = _sector(3, combat, ScenarioResource.new(), ScenarioResource.new(), ScenarioResource.new())
	var second: Array[ScenarioResource] = first.duplicate()
	GameStateManager.place_repair_stations(first, 3, replaceable, station_scenario, Vector2i(1, 2), 1234)
	GameStateManager.place_repair_stations(second, 3, replaceable, station_scenario, Vector2i(1, 2), 1234)
	assert_eq(first, second)


func test_no_room_beyond_a_jump_places_none() -> void:
	var combat := ScenarioResource.new()
	var station_scenario := ScenarioResource.new()
	var scenarios: Array[ScenarioResource] = [combat, combat, ScenarioResource.new(), combat, combat, ScenarioResource.new()]
	GameStateManager.place_repair_stations(scenarios, 2, [combat] as Array[ScenarioResource],
		station_scenario, Vector2i(2, 2), 7)
	assert_false(station_scenario in scenarios)


func test_placing_stations_never_draws_from_the_run_stream() -> void:
	var before: int = RNGManager.get_rng(RNGManager.Bucket.RUN).state
	var combat := ScenarioResource.new()
	var scenarios: Array[ScenarioResource] = _sector(2, combat, ScenarioResource.new(), ScenarioResource.new(), ScenarioResource.new())
	GameStateManager.place_repair_stations(scenarios, 2, [combat] as Array[ScenarioResource],
		ScenarioResource.new(), Vector2i(1, 2), 99)
	assert_eq(RNGManager.get_rng(RNGManager.Bucket.RUN).state, before)
