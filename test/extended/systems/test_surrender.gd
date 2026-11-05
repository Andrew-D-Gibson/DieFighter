extends "res://test/helpers/die_fighter_test.gd"
## The events only one ship hears (PLAYER_ATTACKED_SELF, HULL_CRITICAL), a
## ship that holds its fire, and deeds recorded once. Together they are how a
## crew on death's door surrenders and is spared or executed. Scene-level:
## the ships are real enemy scenes in the tree.

const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const ScenarioManagerScript: GDScript = preload("res://Source/Systems/Game/ScenarioManager/scenario_manager.gd")

const Ev := ScenarioManager.ScenarioEvent

var yielding: ScenarioShipState
var executed: ScenarioShipState
var spared: ScenarioShipState
var fighting: ScenarioShipState
var engine: ScenarioEngine


func before_each() -> void:
	super()
	executed = _state(Enemy.Attitude.AGGRESSIVE)
	spared = _state(Enemy.Attitude.NEUTRAL)
	yielding = _state(Enemy.Attitude.NEUTRAL)
	yielding.holds_fire = true
	yielding.transitions = {Ev.PLAYER_ATTACKED_SELF: executed, Ev.COMBAT_ENDED: spared}
	fighting = _state(Enemy.Attitude.AGGRESSIVE)
	fighting.critical_hull_fraction = 0.5
	fighting.transitions = {Ev.HULL_CRITICAL: yielding}

	# ScenarioEngine.current() reads the scenario manager's engine; neither
	# needs to run, only to say whether a volley is still resolving.
	var manager: ScenarioManager = autofree(ScenarioManagerScript.new())
	engine = autofree(ScenarioEngine.new())
	manager.engine = engine
	Globals.scenario_manager = manager


func _state(attitude: Enemy.Attitude) -> ScenarioShipState:
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	state.attitude = attitude
	return state


func _ship(state: ScenarioShipState) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	ship.scenario_state = state
	add_child_autofree(ship)
	# Every hit goes to the hull, so the fractions below are the hull's, and
	# there's hull enough that no test's hits kill it.
	ship.health.shields = 0
	ship.health.max_health = 20
	ship.health.health = 20
	var actions: Array[EnemyActionResource] = []
	for face: int in range(EnemyActionSelector.SLOT_COUNT):
		actions.append(EnemyActionResource.new())
	ship.turn_actions = actions
	return ship


func _hit(ship: Enemy, amount: int) -> void:
	Events.player_attacked_ship.emit(ship, ship.scenario_state.faction)
	ship.health.take_damage(amount)


func test_only_the_crippled_ship_surrenders_and_it_stands_down() -> void:
	var crippled: Enemy = _ship(fighting)
	var wingman: Enemy = _ship(fighting)

	_hit(crippled, ceili(crippled.health.max_health * 0.6))
	_hit(wingman, 1)

	assert_eq(crippled.scenario_state, yielding)
	assert_eq(wingman.scenario_state, fighting, "a scratch isn't death's door, and nobody else heard")
	for action: EnemyActionResource in crippled.turn_actions:
		assert_not_null(action.silenced_action, "every intent is stood down")


func test_the_volley_that_forced_a_surrender_is_not_an_execution() -> void:
	var crippled: Enemy = _ship(fighting)
	var wingman: Enemy = _ship(fighting)

	engine.currently_processing_queue = true
	_hit(crippled, ceili(crippled.health.max_health * 0.6))
	_hit(crippled, 1)
	assert_eq(crippled.scenario_state, yielding, "the rest of that volley was already in flight")

	engine.currently_processing_queue = false
	engine.finished_processing_queue.emit()
	_hit(wingman, 1)
	assert_eq(crippled.scenario_state, yielding, "a shot at another ship isn't one at this one")

	_hit(crippled, 1)
	assert_eq(crippled.scenario_state, executed)


func test_a_restored_ship_does_not_record_its_deeds_again() -> void:
	var deed: FactionDeed = FactionDeed.new()
	deed.deed = &"spared"
	spared.deeds = [deed]
	var recorded: Array[int] = [0]
	var count_deeds: Callable = func(_ship: Enemy, _deeds: Array[FactionDeed]) -> void: recorded[0] += 1
	Events.ship_deeds_done.connect(count_deeds)

	var restored: Enemy = _ship(fighting)
	restored.restore_state({"state": Enemy.state_key(spared)}, spared)
	restored.trigger_state_effects()
	var entered: Enemy = _ship(yielding)
	entered.force_scenario_state(spared)

	Events.ship_deeds_done.disconnect(count_deeds)
	assert_eq(recorded[0], 1, "only the ship that got there in play counts")
