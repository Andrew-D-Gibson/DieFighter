extends "res://test/helpers/die_fighter_test.gd"
## Playing out an enemy turn: it always ends (a turn nobody acts in must not
## hang the game) and never announces the end of a scenario already left.

const SpyStatus := preload("res://test/helpers/spy_status.gd")

var engine: ScenarioEngine
var _saved_speed: float


func before_each() -> void:
	super()
	_saved_speed = Globals.configured_animation_speed
	engine = add_child_autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager


func after_each() -> void:
	Globals.configured_animation_speed = _saved_speed
	super()


func test_short_turns_stay_readable_and_long_turns_ease_to_three_times_speed() -> void:
	for action_number: int in range(1, 4):
		assert_eq(EnemyTurn.animation_multiplier(action_number), 1.0)
	assert_almost_eq(EnemyTurn.animation_multiplier(5), 1.3965, 0.001)
	assert_almost_eq(EnemyTurn.animation_multiplier(7), 2.2128, 0.001)
	assert_eq(EnemyTurn.animation_multiplier(10), 3.0)
	assert_eq(EnemyTurn.animation_multiplier(25), 3.0)


func test_options_keep_the_base_speed_during_accelerated_playback() -> void:
	Globals.animation_speed = 2.0
	engine.enemy_turn_action_count = 10
	assert_eq(Globals.animation_speed, 6.0)
	assert_eq(OptionsSettings.get_option(OptionsSettings.ANIMATION_SPEED), 2.0)
	OptionsSettings.set_option(OptionsSettings.ANIMATION_SPEED, 1.5)
	assert_eq(Globals.animation_speed, 4.5)
	assert_eq(OptionsSettings.get_option(OptionsSettings.ANIMATION_SPEED), 1.5)


func test_shutdown_drops_the_temporary_speed_immediately() -> void:
	Globals.animation_speed = 2.0
	engine.enemy_turn_action_count = 10
	engine.shutdown()
	assert_eq(Globals.animation_speed, 2.0)
	assert_eq(engine.enemy_turn_action_count, -1)


func test_the_next_turn_starts_fresh_and_resets_before_announcing_its_end() -> void:
	engine.enemy_turn_action_count = 10
	var counts: Array[int] = []
	Events.enemy_turn_starting.connect(func() -> void:
		counts.append(engine.enemy_turn_action_count), CONNECT_ONE_SHOT)
	Events.enemy_turn_over.connect(func() -> void:
		counts.append(engine.enemy_turn_action_count), CONNECT_ONE_SHOT)
	await EnemyTurn.play(_no_ships, get_tree())
	assert_eq(counts, [0, -1] as Array[int])
	assert_eq(Globals.animation_speed, Globals.configured_animation_speed)


func test_a_missing_die_does_not_advance_the_speed_curve() -> void:
	engine.enemy_turn_action_count = 3
	var event: EnemyActionEvent = EnemyActionEvent.new()
	await event.resolve(engine)
	assert_eq(engine.enemy_turn_action_count, 3)


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
