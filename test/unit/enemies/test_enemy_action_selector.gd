extends "res://test/helpers/die_fighter_test.gd"
## EnemyActionSelector: how a ship's six intent slots are rolled, and which
## options a situation leaves out. The rule that matters most: nothing that
## takes a ship off the board can be rolled into a table the player can't read.

const Cat := EffectEnums.Category
const Ships := preload("res://test/helpers/ships.gd")
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


# ── Face bias: which faces the strong actions land on ──────────────────────────

func _wait() -> EnemyActionResource:
	return _action("Wait")


func _attack_option(amount: int, label: String = "Attack") -> EnemyActionOptionResource:
	var attack := Ships.attack()
	attack.name = label
	var option := Ships.option(attack, 0.0, amount, amount)
	option.force_include = true
	return option


## The face (1-6) the named action landed on, or 0.
func _face_of(actions: Array[EnemyActionResource], action_name: String) -> int:
	return _names(actions).find(action_name) + 1


func test_damage_outranks_a_consequence_outranks_nothing() -> void:
	var attack := Ships.attack()
	var shield := _action("Shield", [Effects.shield()])
	shield.intent_amount = 50
	assert_gt(attack.placement_strength(), shield.placement_strength(),
		"any damage outranks any shield, however big")
	assert_gt(shield.placement_strength(), _wait().placement_strength())


func test_a_bigger_amount_outranks_a_smaller_one_of_the_same_tier() -> void:
	var small := Ships.attack()
	small.intent_amount = 3
	var big := Ships.attack()
	big.intent_amount = 6
	assert_gt(big.placement_strength(), small.placement_strength())


func test_a_tier_override_replaces_the_derived_tier() -> void:
	var shield := _action("Shield", [Effects.shield()])
	var option := Ships.option(shield)
	option.strength_tier_override = 2.5
	var rolled := option.get_action()
	var attack := Ships.attack()
	attack.intent_amount = 10
	assert_gt(rolled.placement_strength(), attack.placement_strength())


func test_a_holograms_amount_is_a_face_not_a_strength() -> void:
	var low := Ships.loader()
	low.intent_amount = 1
	var high := Ships.loader()
	high.intent_amount = 6
	assert_eq(low.placement_strength(), high.placement_strength())


func test_no_bias_rolls_exactly_what_it_always_has() -> void:
	var pool := _pool([_attack_option(4), _option(_wait()), _option(_action("Shield", [Effects.shield()]))])
	var before: Array = []
	for i: int in range(20):
		before.append(_names(EnemyActionSelector.roll(pool, _situation(true))))
	RNGManager.seed_scenario(1234)
	for i: int in range(20):
		assert_eq(_names(EnemyActionSelector.roll(pool, _situation(true), [], 0.0)), before[i])


func test_a_strong_bias_puts_the_attack_on_the_six() -> void:
	var pool := _pool([_attack_option(4), _option(_wait())])
	for i: int in range(100):
		assert_eq(_face_of(EnemyActionSelector.roll(pool, _situation(true), [], 3.0), "Attack"), 6)


func test_a_strong_negative_bias_puts_the_attack_on_the_one() -> void:
	var pool := _pool([_attack_option(4), _option(_wait())])
	for i: int in range(100):
		assert_eq(_face_of(EnemyActionSelector.roll(pool, _situation(true), [], -3.0), "Attack"), 1)


func test_a_mild_bias_only_leans() -> void:
	var pool := _pool([_attack_option(4), _option(_wait())])
	var high: int = 0
	var faces: Dictionary[int, bool] = {}
	for i: int in range(300):
		var face: int = _face_of(EnemyActionSelector.roll(pool, _situation(true), [], 0.5), "Attack")
		faces[face] = true
		if face >= 4:
			high += 1
	assert_gt(high, 200, "mostly on the high faces")
	assert_true(faces.has(1) or faces.has(2) or faces.has(3), "but not always")


func test_a_bigger_hit_lands_on_a_higher_face() -> void:
	var pool := _pool([_attack_option(3, "Small"), _attack_option(6, "Big"), _option(_wait())])
	for i: int in range(100):
		var actions := EnemyActionSelector.roll(pool, _situation(true), [], 6.0)
		assert_eq(_face_of(actions, "Big"), 6)
		assert_eq(_face_of(actions, "Small"), 5)


func test_a_pool_override_wins_over_the_enemy_bias() -> void:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE))
	autofree(ship.health)
	Ships.give_pool(ship, [Ships.option(_wait())])
	ship.enemy_resource.face_bias = 1.5
	assert_eq(ship._current_face_bias(), 1.5)

	var pool: EnemyTurnActionList = ship.enemy_resource.action_options[0]
	pool.override_face_bias = true
	pool.face_bias = 0.0
	assert_eq(ship._current_face_bias(), 0.0, "an override of 0 still counts")


# ── Held faces: a die the ship kept picks where its pinned action goes ────────

func _pinned_option(label: String) -> EnemyActionOptionResource:
	var option := _attack_option(9, label)
	option.place_on_held_faces = true
	return option


func _holding(faces: Array[int]) -> EnemyActionSituation:
	var situation := _situation(true)
	situation.held_faces = faces
	return situation


func test_a_pinned_action_lands_on_the_held_face() -> void:
	var pool := _pool([_pinned_option("Shot"), _option(_wait())])
	for face: int in range(1, 7):
		for i: int in range(20):
			var actions := EnemyActionSelector.roll(pool, _holding([face]), [], 1.0)
			assert_eq(_face_of(actions, "Shot"), face)
			assert_eq(actions[face - 1].activating_die_number, face, "the slot is renumbered")


func test_a_pin_overrides_face_bias() -> void:
	var pool := _pool([_pinned_option("Shot"), _option(_wait())])
	var actions := EnemyActionSelector.roll(pool, _holding([1]), [], 6.0)
	assert_eq(_face_of(actions, "Shot"), 1)


func test_each_pinned_action_takes_its_own_held_face() -> void:
	var pool := _pool([_pinned_option("A"), _pinned_option("B"), _option(_wait())])
	var actions := EnemyActionSelector.roll(pool, _holding([2, 5]), [], 0.0)
	assert_eq(_face_of(actions, "A"), 2)
	assert_eq(_face_of(actions, "B"), 5)


func test_a_spare_pinned_action_still_appears_somewhere() -> void:
	var pool := _pool([_pinned_option("A"), _pinned_option("B"), _option(_wait())])
	var actions := EnemyActionSelector.roll(pool, _holding([4]), [], 0.0)
	assert_eq(_face_of(actions, "A"), 4)
	assert_gt(_face_of(actions, "B"), 0)


func test_holding_nothing_leaves_the_roll_unchanged() -> void:
	var pool := _pool([_pinned_option("Shot"), _option(_wait())])
	RNGManager.seed_scenario(77)
	var pinned := _names(EnemyActionSelector.roll(pool, _holding([]), [], 0.5))
	pool.actions_possible[0].place_on_held_faces = false
	RNGManager.seed_scenario(77)
	assert_eq(_names(EnemyActionSelector.roll(pool, _holding([]), [], 0.5)), pinned)


func test_the_siege_mortar_loads_its_shot_on_the_held_face() -> void:
	var mortar: EnemyResource = load("res://Source/Content/Enemies/EnemyResources/siege_mortar.tres")
	var loaded: EnemyTurnActionList = mortar.action_options[1]
	var actions := EnemyActionSelector.roll(loaded, _holding([3]), [], mortar.face_bias)
	assert_eq(actions[2].name, "Siege Shot")
