extends "res://test/helpers/die_fighter_test.gd"
## The AutoPilot at a repair station: which repairs and sales it may make, that
## making them goes through the same handlers a player's input reaches, and
## when the heuristic bot repairs.

const STATION_SCENE: PackedScene = preload("res://Source/Systems/Game/RepairStation/repair_station.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")

var station: RepairStation
var grid: TileGrid
var player: Player


func before_each() -> void:
	super()
	grid = TileGrid.new()
	grid.position = Vector2(88, 90)
	add_child_autofree(grid)
	Globals.tile_grid = grid

	player = make_player()
	var health: Health = autofree(Health.new())
	health.max_health = 32
	health.health = 12
	player.health = health
	player.money = 40
	Globals.player = player

	station = STATION_SCENE.instantiate()
	station.position = Vector2(122, 43)
	add_child_autofree(station)
	station._open_station()


## A tile on the grid and in the tree, as a player sees it: only those can be
## picked up.
func _place(cell: Vector2i) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = TileResource.new()
	grid.add_child(tile)
	grid._assign_tile_to_grid_pos(tile, cell)
	# As a saved or received tile is: its drops go to the grid.
	grid._listen_to_drags(tile)
	return tile


func _of_kind(moves: Array[AutoPilotMove], kind: AutoPilotMove.Kind) -> Array[AutoPilotMove]:
	return moves.filter(func(move: AutoPilotMove) -> bool: return move.kind == kind)


func test_a_repair_is_offered_when_hurt_and_affordable() -> void:
	var repairs: Array[AutoPilotMove] = _of_kind(AutoPilotMove._repair_station_moves(), AutoPilotMove.Kind.REPAIR)
	assert_eq(repairs.size(), 1)
	assert_eq(repairs[0].price, 10)
	assert_eq(repairs[0].describe(), {"move": "repair", "price": 10})


func test_no_repair_is_offered_at_full_hull_or_when_broke() -> void:
	player.health.health = 32
	assert_eq(_of_kind(AutoPilotMove._repair_station_moves(), AutoPilotMove.Kind.REPAIR).size(), 0)
	player.health.health = 12
	player.money = 5
	assert_eq(_of_kind(AutoPilotMove._repair_station_moves(), AutoPilotMove.Kind.REPAIR).size(), 0)


func test_a_closed_station_offers_nothing() -> void:
	_place(Vector2i(0, 0))
	_place(Vector2i(1, 0))
	station._close_station()
	assert_eq(AutoPilotMove._repair_station_moves().size(), 0)


func test_every_tile_but_the_last_is_offered_for_sale() -> void:
	_place(Vector2i(0, 0))
	_place(Vector2i(1, 0))
	var sales: Array[AutoPilotMove] = _of_kind(AutoPilotMove._repair_station_moves(), AutoPilotMove.Kind.SELL)
	assert_eq(sales.size(), 2)
	assert_eq(sales[0].price, 7)


func test_a_lone_tile_is_never_offered_for_sale() -> void:
	_place(Vector2i(0, 0))
	assert_eq(_of_kind(AutoPilotMove._repair_station_moves(), AutoPilotMove.Kind.SELL).size(), 0)


func test_a_repair_move_buys_a_repair() -> void:
	AutoPilotMove.repair(station.repair_cost()).perform()
	assert_eq(player.health.health, 18)
	assert_eq(player.money, 30)


func test_a_sell_move_drops_the_tile_on_the_slot() -> void:
	_place(Vector2i(0, 0))
	var sold: Tile = _place(Vector2i(1, 0))
	AutoPilotMove.sell(sold, station.sell_price(sold.tile_resource)).perform()
	assert_eq(player.money, 47)
	assert_true(grid.is_grid_pos_open(Vector2i(1, 0)))


func test_the_smart_bot_repairs_a_low_hull_and_stops_near_full() -> void:
	var smart: HeuristicPolicy = HeuristicPolicy.new(HeuristicPolicy.persona("smart"))
	player.health.health = 12
	assert_true(smart._wants_repair())
	player.health.health = 26
	assert_false(smart._wants_repair())


func test_a_turtle_tops_up_further_than_an_aggressive_bot() -> void:
	player.health.health = 24
	assert_true(HeuristicPolicy.new(HeuristicPolicy.persona("turtle"))._wants_repair())
	assert_false(HeuristicPolicy.new(HeuristicPolicy.persona("aggressive"))._wants_repair())
