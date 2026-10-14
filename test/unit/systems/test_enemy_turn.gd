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
