extends "res://test/helpers/die_fighter_test.gd"
## Playing out an enemy turn: it always ends (a turn nobody acts in must not
## hang the game) and never announces the end of a scenario already left.

const SpyStatus := preload("res://test/helpers/spy_status.gd")

var engine: ScenarioEngine


func before_each() -> void:
	super()
	engine = add_child_autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager


func _no_ships() -> Array[Enemy]:
	return []


func test_a_turn_where_nobody_holds_a_die_still_ends() -> void:
	watch_signals(Events)
	await EnemyTurn.play(_no_ships, get_tree())
	assert_signal_emitted(Events, "enemy_turn_starting")
	assert_signal_emitted(Events, "enemy_turn_over")


func test_a_turn_in_a_scenario_already_left_ends_silently() -> void:
	engine.shutdown()
	watch_signals(Events)
	await EnemyTurn.play(_no_ships, get_tree())
	assert_signal_not_emitted(Events, "enemy_turn_over")


func test_statuses_tick_before_the_roster_is_read() -> void:
	var order: Array[String] = []
	var spy: StatusModifier = SpyStatus.new()
	spy.ticked.connect(func() -> void: order.append("tick"))
	engine.add_modifier(spy)
	var roster: Callable = func() -> Array[Enemy]:
		order.append("roster")
		return []
	await EnemyTurn.play(roster, get_tree())
	assert_eq(order, ["tick", "roster"])


## A ship that logs its turns and passes dice by hand, standing in for the
## real dice and actions.
class TurnShip extends Enemy:
	var log: Array[String]
	var held: int = 0
	## Where each die it spends goes. Null spends it for good.
	var relay_to: TurnShip

	func holds_dice() -> bool:
		return held > 0

	func has_dice_to_spend() -> bool:
		return held > 0

	func run_turn() -> void:
		log.append(name + ":turn")
		_spend()

	func run_relayed_dice() -> void:
		log.append(name + ":relayed")
		_spend()

	func _spend() -> void:
		if relay_to:
			relay_to.held += held
		held = 0


func _turn_ship(ship_name: String, held: int, log: Array[String]) -> TurnShip:
	var made: TurnShip = autofree(TurnShip.new())
	made.name = ship_name
	made.held = held
	made.log = log
	made.health = autofree(Health.new())
	made.health.max_health = 5
	made.health.health = 5
	return made


func test_a_die_relayed_to_a_ship_that_already_went_is_spent_after_everyone_else() -> void:
	var log: Array[String] = []
	var b := _turn_ship("B", 1, log)
	var a := _turn_ship("A", 1, log)
	var c := _turn_ship("C", 1, log)
	a.relay_to = b
	var ships: Array[Enemy] = [b, a, c]
	await EnemyTurn.play(func() -> Array[Enemy]: return ships, get_tree())
	assert_eq(log, ["B:turn", "A:turn", "C:turn", "B:relayed"] as Array[String])


func test_a_die_relayed_ahead_is_spent_on_that_ships_own_turn() -> void:
	var log: Array[String] = []
	var a := _turn_ship("A", 1, log)
	var b := _turn_ship("B", 0, log)
	a.relay_to = b
	var ships: Array[Enemy] = [a, b]
	await EnemyTurn.play(func() -> Array[Enemy]: return ships, get_tree())
	assert_eq(log, ["A:turn", "B:turn"] as Array[String])
	assert_eq(b.held, 0)
