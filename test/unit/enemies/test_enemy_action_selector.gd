extends "res://test/helpers/die_fighter_test.gd"
## EnemyActionSelector: how a ship's six intent slots are rolled, and which
## options a situation leaves out. The rule that matters most: nothing that
## takes a ship off the board can be rolled into a table the player can't read.

const Cat := EffectEnums.Category
const CIVILIAN_TRANSPORT := "res://Source/Content/Enemies/EnemyResources/civilian_transport.tres"


func before_each() -> void:
	super()
	RNGManager.seed_scenario(1234)


func _action(action_name: String, effects: Array[EffectData] = []) -> EnemyActionResource:
	var action := EnemyActionResource.new()
	action.name = action_name
	action.effect_chain = Effects.chain(effects)
	return action


func _flee_action() -> EnemyActionResource:
	return _action("Flee", [Effects.data(Cat.SCENARIO_CONTROL, EffectEnums.ScenarioControlSubtype.FLEE)])


func _option(action: EnemyActionResource, weight: float = 1.0, force_include: bool = false) -> EnemyActionOptionResource:
	var option := EnemyActionOptionResource.new()
	option.base_action = action
	option.weight = weight
	option.force_include = force_include
	return option


func _pool(options: Array[EnemyActionOptionResource]) -> EnemyTurnActionList:
	var pool := EnemyTurnActionList.new()
	pool.actions_possible = options
	return pool


func _situation(intents_visible: bool) -> EnemyActionSituation:
	var situation := EnemyActionSituation.new()
	situation.intents_visible = intents_visible
	return situation


func _names(actions: Array[EnemyActionResource]) -> Array[String]:
	var out: Array[String] = []
	for action: EnemyActionResource in actions:
		out.append(action.name)
	return out


# ── Safety, read off the chain ─────────────────────────────────────────────────

func test_an_ordinary_action_is_safe_while_hidden() -> void:
	var attack := _action("Attack", [Effects.die_value(), Effects.damage()])
	assert_true(attack.is_safe_while_hidden())


func test_an_action_with_no_chain_is_safe_while_hidden() -> void:
	assert_true(EnemyActionResource.new().is_safe_while_hidden())


func test_fleeing_is_not_safe_while_hidden() -> void:
	assert_false(_flee_action().is_safe_while_hidden())


func test_jumping_is_not_safe_while_hidden() -> void:
	var jump := _action("Jump", [Effects.data(Cat.SCENARIO_CONTROL, EffectEnums.ScenarioControlSubtype.JUMP)])
	assert_false(jump.is_safe_while_hidden())


func test_a_flee_inside_either_branch_of_a_conditional_is_not_safe() -> void:
	var flee: Array[EffectData] = [Effects.data(Cat.SCENARIO_CONTROL, EffectEnums.ScenarioControlSubtype.FLEE)]
	var none: Array[EffectData] = []
	var in_true := _action("A", [Effects.conditional(EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, flee, none)])
	var in_false := _action("B", [Effects.conditional(EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, none, flee)])
	assert_false(in_true.is_safe_while_hidden())
	assert_false(in_false.is_safe_while_hidden())


# ── The roll ───────────────────────────────────────────────────────────────────

func test_a_roll_fills_and_numbers_all_six_slots() -> void:
	var pool := _pool([_option(_action("Attack")), _option(_action("Shield"))])
	var actions := EnemyActionSelector.roll(pool, _situation(true))
	assert_eq(actions.size(), EnemyActionSelector.SLOT_COUNT)
	for i: int in range(actions.size()):
		assert_eq(actions[i].activating_die_number, i + 1)


func test_force_include_always_appears() -> void:
	var pool := _pool([_option(_action("Attack"), 1.0), _option(_action("Signature"), 0.0, true)])
	for i: int in range(50):
		var names := _names(EnemyActionSelector.roll(pool, _situation(true)))
		assert_eq(names.count("Signature"), 1)


func test_forced_actions_that_fill_the_table_keep_their_order() -> void:
	var forced: Array[EnemyActionResource] = []
	for i: int in range(6):
		forced.append(_action("Forced %d" % i))
	var pool := _pool([_option(_action("Attack"))])
	var names := _names(EnemyActionSelector.roll(pool, _situation(true), forced))
	assert_eq(names, ["Forced 0", "Forced 1", "Forced 2", "Forced 3", "Forced 4", "Forced 5"])


# ── Hidden intents ─────────────────────────────────────────────────────────────

func test_hidden_tables_never_roll_flee() -> void:
	var pool := _pool([_option(_action("Wait"), 1.0), _option(_flee_action(), 5.0)])
	for i: int in range(100):
		assert_does_not_have(_names(EnemyActionSelector.roll(pool, _situation(false))), "Flee")


func test_a_force_included_flee_is_skipped_while_hidden() -> void:
	var pool := _pool([_option(_action("Wait"), 1.0), _option(_flee_action(), 0.0, true)])
	assert_does_not_have(_names(EnemyActionSelector.roll(pool, _situation(false))), "Flee")
	assert_has(_names(EnemyActionSelector.roll(pool, _situation(true))), "Flee")


func test_a_pool_with_nothing_allowed_fills_with_do_nothing() -> void:
	var pool := _pool([_option(_flee_action(), 1.0, true)])
	var actions := EnemyActionSelector.roll(pool, _situation(false))
	assert_eq(actions.size(), EnemyActionSelector.SLOT_COUNT)
	for action: EnemyActionResource in actions:
		assert_true(action.is_safe_while_hidden())
		assert_eq(action.get_threat(), EnemyActionResource.Threat.DEAD)


func test_the_civilian_transport_never_flees_from_a_hidden_table() -> void:
	# The bug this guards against: firing on a friendly transport you can't
	# read, and watching it flee on the very die you shot it with.
	var transport: EnemyResource = load(CIVILIAN_TRANSPORT)
	var pool: EnemyTurnActionList = transport.action_options[0]
	for i: int in range(500):
		for action: EnemyActionResource in EnemyActionSelector.roll(pool, _situation(false)):
			assert_true(action.is_safe_while_hidden(), "rolled %s while hidden" % action.name)
			if not action.is_safe_while_hidden():
				return


func test_the_civilian_transport_still_flees_once_it_can_be_read() -> void:
	var transport: EnemyResource = load(CIVILIAN_TRANSPORT)
	var actions := EnemyActionSelector.roll(transport.action_options[0], _situation(true))
	var unsafe: int = 0
	for action: EnemyActionResource in actions:
		if not action.is_safe_while_hidden():
			unsafe += 1
	assert_gt(unsafe, 0, "Flee is force_include, so a readable table carries it")
