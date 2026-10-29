extends "res://test/helpers/die_fighter_test.gd"
## EnemyActionSelector: how a ship's six intent slots are rolled, and which
## options a situation leaves out. The rule that matters most: nothing that
## takes a ship off the board can be rolled into a table the player can't read.

const Cat := EffectEnums.Category
const Ships := preload("res://test/helpers/ships.gd")
const CIVILIAN_TRANSPORT := "res://Source/Content/Enemies/EnemyResources/civilian_transport.tres"
const _DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")


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


func test_forced_actions_are_copied_so_numbering_never_touches_the_originals() -> void:
	var forced: Array[EnemyActionResource] = [_action("Forced")]
	var pool := _pool([_option(_action("Attack"))])
	var table: Array[EnemyActionResource] = EnemyActionSelector.roll(pool, _situation(true), forced)
	assert_does_not_have(table, forced[0])
	assert_eq(forced[0].activating_die_number, 0, "the tutorial's queued resource is untouched")


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


# ── Kept faces: a loaded payoff appears only where the ship kept a die ──────

func _kept_option(label: String) -> EnemyActionOptionResource:
	var attack := Ships.attack()
	attack.name = label
	var option := Ships.option(attack, 5.0, 9, 9)
	option.force_include = true
	option.fills_kept_faces = true
	return option


func _keeping(faces: Array[int]) -> EnemyActionSituation:
	var situation := _situation(true)
	situation.kept_faces = faces
	return situation


func test_a_kept_face_option_never_appears_without_a_kept_die() -> void:
	var pool := _pool([_kept_option("Shot"), _option(_wait())])
	for i: int in range(100):
		var actions := EnemyActionSelector.roll(pool, _keeping([]), [], 1.0)
		assert_eq(_face_of(actions, "Shot"), 0, "weight and force_include are ignored")
		assert_eq(actions.size(), 6)


func test_a_kept_face_option_is_never_available_to_an_ordinary_slot() -> void:
	assert_false(EnemyActionSelector.is_available(_kept_option("Shot"), _situation(true)))


func test_a_kept_die_gets_the_payoff_on_its_face() -> void:
	var pool := _pool([_kept_option("Shot"), _option(_wait())])
	for face: int in range(1, 7):
		for i: int in range(20):
			var actions := EnemyActionSelector.roll(pool, _keeping([face]), [], 6.0)
			assert_eq(_names(actions).count("Shot"), 1)
			assert_eq(_face_of(actions, "Shot"), face)
			assert_eq(actions[face - 1].activating_die_number, face, "the slot is numbered")


func test_each_kept_face_gets_its_own_copy() -> void:
	var pool := _pool([_kept_option("Shot"), _option(_wait())])
	var actions := EnemyActionSelector.roll(pool, _keeping([2, 5]), [], 0.0)
	assert_eq(_names(actions).count("Shot"), 2)
	assert_eq(actions[1].name, "Shot")
	assert_eq(actions[4].name, "Shot")
	assert_eq(actions.size(), 6)


func test_nothing_kept_rolls_exactly_what_it_would_without_the_option() -> void:
	RNGManager.seed_scenario(77)
	var with_option := _names(EnemyActionSelector.roll(
		_pool([_kept_option("Shot"), _attack_option(3), _option(_wait())]), _keeping([]), [], 0.5))
	RNGManager.seed_scenario(77)
	var without := _names(EnemyActionSelector.roll(
		_pool([_attack_option(3), _option(_wait())]), _keeping([]), [], 0.5))
	assert_eq(with_option, without)


## A die out of the tree (Dice reach for game systems) showing [param face].
func _die(face: int) -> Dice:
	var die: Dice = autofree(_DICE_SCENE.instantiate())
	die.value = face
	return die


## A pirate with a dice queue in the tree (DiceQueue.add reads its position).
func _holder() -> Enemy:
	var ship: Enemy = autofree(Ships.ship(ScenarioManager.Faction.PIRATE))
	autofree(ship.health)
	ship.dice_manager = add_child_autofree(EnemyDiceManager.new())
	return ship


func test_only_dice_the_ship_kept_itself_count() -> void:
	var ship := _holder()
	var handed := _die(2)
	var kept := _die(4)
	ship.dice_manager.queue.append(handed)
	ship.dice_manager.queue.append(kept)
	ship.kept_dice.append(kept)
	assert_eq(EnemyActionSituation.for_ship(ship, [ship]).kept_faces, [4] as Array[int])


func test_a_kept_die_taken_back_no_longer_counts() -> void:
	var ship := _holder()
	ship.kept_dice.append(_die(4))
	assert_eq(EnemyActionSituation.for_ship(ship, [ship]).kept_faces, [] as Array[int])


func test_keeping_a_die_records_it_on_the_ship() -> void:
	var ship := _holder()
	var event := KeepDieWithActorEvent.new()
	event.actor = ship
	event.activator_die = _die(3)
	event.resolve(null)
	assert_eq(ship.kept_dice.size(), 1)
	assert_true(event.activator_die in ship.dice_manager.queue)


func test_the_siege_mortar_only_fires_siege_shot_from_a_loaded_die() -> void:
	var mortar: EnemyResource = load("res://Source/Content/Enemies/EnemyResources/siege_mortar.tres")
	for pool: EnemyTurnActionList in mortar.action_options:
		for i: int in range(50):
			var actions := EnemyActionSelector.roll(pool, _keeping([]), [], mortar.face_bias)
			assert_false("Siege Shot" in _names(actions))
	var loaded := EnemyActionSelector.roll(mortar.action_options[1], _keeping([3]), [], mortar.face_bias)
	assert_eq(_names(loaded).count("Siege Shot"), 1)
	assert_eq(loaded[2].name, "Siege Shot")


# ── Venting statuses: only a ship with a status to give rolls it ────────────

const PURGE_VENTS := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/purge_vents.tres"
const DEFENDER := "res://Source/Content/Enemies/EnemyResources/defender.tres"


func _with_statuses(ids: Array[StringName]) -> EnemyActionSituation:
	var situation := _situation(true)
	situation.statuses = ids
	return situation


func test_purge_vents_is_read_as_venting_its_statuses() -> void:
	assert_true((load(PURGE_VENTS) as EnemyActionResource).vents_own_statuses())
	assert_false(_action("Attack", [Effects.die_value(), Effects.damage()]).vents_own_statuses())


func test_a_vent_is_never_rolled_for_a_ship_with_no_status() -> void:
	# No authored condition: the gate is read off the chain, so a new vent
	# can't forget it.
	var pool := _pool([_option(_action("Wait"), 1.0), _option(load(PURGE_VENTS), 5.0, true)])
	for i: int in range(50):
		assert_does_not_have(_names(EnemyActionSelector.roll(pool, _with_statuses([]))), "Purge Vents")


func test_a_vent_is_rolled_once_the_ship_has_a_status() -> void:
	var pool := _pool([_option(_action("Wait"), 1.0), _option(load(PURGE_VENTS), 5.0, true)])
	assert_has(_names(EnemyActionSelector.roll(pool, _with_statuses([&"burn"]))), "Purge Vents")


func test_the_defender_only_vents_when_it_has_something_to_vent() -> void:
	var defender: EnemyResource = load(DEFENDER)
	var vented_with_status: bool = false
	for pool: EnemyTurnActionList in defender.action_options:
		for i: int in range(50):
			assert_does_not_have(_names(EnemyActionSelector.roll(pool, _with_statuses([]))), "Purge Vents")
			if "Purge Vents" in _names(EnemyActionSelector.roll(pool, _with_statuses([&"jammed"]))):
				vented_with_status = true
	assert_true(vented_with_status, "a defender with a status vents now and then")
