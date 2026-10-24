extends "res://test/helpers/die_fighter_test.gd"
## EnemyActionVariety: the per-sector cap on how many kinds of action one
## ship's table may mix. Blank faces and kept-face payoffs don't count, the
## kinds kept are drawn by how much of the table each would fill, and a cap
## that doesn't bind leaves the roll exactly as it was.

const ROLLS: int = 200


func before_each() -> void:
	super()
	RNGManager.seed_scenario(4321)


func _action(action_name: String) -> EnemyActionResource:
	var action := EnemyActionResource.new()
	action.name = action_name
	var effects: Array[EffectData] = [Effects.damage()]
	action.effect_chain = Effects.chain(effects)
	return action


func _option(action_name: String, weight: float = 1.0, force_include: bool = false) -> EnemyActionOptionResource:
	var option := EnemyActionOptionResource.new()
	option.base_action = _action(action_name)
	option.weight = weight
	option.force_include = force_include
	return option


func _pool(options: Array[EnemyActionOptionResource]) -> EnemyTurnActionList:
	var pool := EnemyTurnActionList.new()
	pool.actions_possible = options
	return pool


func _capped(cap: int) -> EnemyActionSituation:
	var situation := EnemyActionSituation.new()
	situation.max_action_kinds = cap
	return situation


func _names(actions: Array[EnemyActionResource]) -> Array[String]:
	var out: Array[String] = []
	for action: EnemyActionResource in actions:
		out.append(action.name)
	return out


func _four_kinds() -> EnemyTurnActionList:
	return _pool([_option("Attack"), _option("Shield"), _option("Lockout"), _option("Quake")])


# ── The cap ─────────────────────────────────────────────────────────────────

func test_a_capped_table_never_mixes_more_kinds_than_the_cap() -> void:
	var pool := _four_kinds()
	for cap: int in [1, 2, 3]:
		for i: int in range(ROLLS):
			var table := EnemyActionSelector.roll(pool, _capped(cap))
			assert_lte(EnemyActionVariety.count_kinds(table), cap)
			assert_eq(table.size(), EnemyActionSelector.SLOT_COUNT)


func test_no_cap_rolls_exactly_what_it_always_has() -> void:
	var pool := _four_kinds()
	RNGManager.seed_scenario(7)
	var uncapped := _names(EnemyActionSelector.roll(pool, EnemyActionSituation.new()))
	RNGManager.seed_scenario(7)
	assert_eq(_names(EnemyActionSelector.roll(pool, _capped(0))), uncapped)


func test_a_cap_that_does_not_bind_rolls_exactly_what_it_always_has() -> void:
	var pool := _pool([_option("Attack"), _option("Shield"), _option("")])
	RNGManager.seed_scenario(7)
	var uncapped := _names(EnemyActionSelector.roll(pool, _capped(0)))
	RNGManager.seed_scenario(7)
	assert_eq(_names(EnemyActionSelector.roll(pool, _capped(2))), uncapped,
		"two kinds under a cap of two draws nothing extra")


func test_blank_faces_are_not_a_kind() -> void:
	var pool := _pool([_option("Attack"), _option("Shield"), _option("", 4.0)])
	var saw_blank: bool = false
	for i: int in range(ROLLS):
		var table := EnemyActionSelector.roll(pool, _capped(1))
		assert_lte(EnemyActionVariety.count_kinds(table), 1)
		saw_blank = saw_blank or "" in _names(table)
	assert_true(saw_blank, "Do Nothing still turns up beside the one kind")


# ── Which kinds make the cut ───────────────────────────────────────────────────

func test_a_heavily_weighted_kind_is_usually_the_one_kept() -> void:
	var pool := _pool([_option("Attack", 10.0), _option("Shield"), _option("Lockout")])
	var attacks: int = 0
	for i: int in range(ROLLS):
		if "Attack" in _names(EnemyActionSelector.roll(pool, _capped(1))):
			attacks += 1
	assert_gt(attacks, ROLLS * 3 / 4)


func test_every_kind_gets_its_turn() -> void:
	var pool := _four_kinds()
	var seen: Array[String] = []
	for i: int in range(ROLLS):
		for action_name: String in _names(EnemyActionSelector.roll(pool, _capped(1))):
			if action_name not in seen:
				seen.append(action_name)
	seen.sort()
	assert_eq(seen, ["Attack", "Lockout", "Quake", "Shield"] as Array[String])


func test_a_force_included_kind_can_be_left_out() -> void:
	var pool := _pool([_option("Siphon", 0.0, true), _option("Attack", 3.0), _option("Ion", 2.0)])
	var without_siphon: int = 0
	for i: int in range(ROLLS):
		var table := EnemyActionSelector.roll(pool, _capped(1))
		assert_lte(EnemyActionVariety.count_kinds(table), 1)
		if "Siphon" not in _names(table):
			without_siphon += 1
	assert_gt(without_siphon, 0, "force_include only promises a copy when its kind is in play")
	assert_lt(without_siphon, ROLLS, "and it is in play now and then")


func test_forced_slots_keep_their_kinds_and_count_toward_the_cap() -> void:
	var forced: Array[EnemyActionResource] = [_action("Shield")]
	for i: int in range(ROLLS):
		var table := EnemyActionSelector.roll(_four_kinds(), _capped(2), forced)
		assert_has(_names(table), "Shield")
		assert_lte(EnemyActionVariety.count_kinds(table), 2)


func test_a_kept_face_payoff_does_not_count_toward_the_cap() -> void:
	var payoff := _option("Shot")
	payoff.fills_kept_faces = true
	var pool := _pool([payoff, _option("Attack"), _option("Shield")])
	var situation := _capped(1)
	situation.kept_faces = [3] as Array[int]
	for i: int in range(ROLLS):
		var table := EnemyActionSelector.roll(pool, situation)
		assert_eq(table[2].name, "Shot")
		var rest := table.duplicate()
		rest.remove_at(2)
		assert_eq(EnemyActionVariety.count_kinds(rest), 1)


# ── Rerolling one slot ───────────────────────────────────────────────────────

func _table(names: Array[String]) -> Array[EnemyActionResource]:
	var out: Array[EnemyActionResource] = []
	for action_name: String in names:
		out.append(_action(action_name))
	return out


func test_a_reroll_at_the_cap_brings_in_no_new_kind() -> void:
	var pool := _pool([_option("Attack"), _option("Shield"), _option("Lockout", 50.0)])
	for i: int in range(ROLLS):
		var table := _table(["Attack", "Shield", "Attack", "Shield", "Attack", "Shield"])
		EnemyActionSelector.reroll_slot_without_relays(pool, _capped(2), table, 0)
		assert_ne(table[0].name, "Lockout")


func test_a_reroll_with_room_may_bring_in_a_new_kind() -> void:
	var pool := _pool([_option("Attack"), _option("Shield"), _option("Lockout", 50.0)])
	var lockouts: int = 0
	for i: int in range(ROLLS):
		var table := _table(["Attack", "Shield", "Attack", "Shield", "Attack", "Shield"])
		EnemyActionSelector.reroll_slot_without_relays(pool, _capped(3), table, 0)
		if table[0].name == "Lockout":
			lockouts += 1
	assert_gt(lockouts, 0)


# ── The run's dial ───────────────────────────────────────────────────────────

func test_the_cap_follows_the_sector_and_the_last_entry_carries_on() -> void:
	var manager: GameStateManager = autofree(GameStateManager.new())
	manager.current_game_save = GameSaveResource.new()
	manager.action_kinds_per_sector = [2, 3, 0] as Array[int]
	var caps: Array[int] = []
	for sector: int in range(5):
		manager.current_game_save.sector_index = sector
		caps.append(manager.get_action_kinds_cap())
	assert_eq(caps, [2, 3, 0, 0, 0] as Array[int])


func test_an_empty_dial_means_no_cap() -> void:
	var manager: GameStateManager = autofree(GameStateManager.new())
	manager.current_game_save = GameSaveResource.new()
	manager.action_kinds_per_sector = [] as Array[int]
	assert_eq(manager.get_action_kinds_cap(), 0)
