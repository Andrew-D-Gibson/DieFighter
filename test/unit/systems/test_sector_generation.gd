extends "res://test/helpers/die_fighter_test.gd"
## Which encounters a sector may be dealt, rolled from the real lists on
## main.tscn's GameStateManager.
##
## Sector 1 is for learning to read one ship's table at a time, so a ship that
## shields, repairs or feeds an ally waits for sector 2. The gate is read off
## the ships' actions, not a list of names.

const MAIN_SCENE: String = "res://Source/Scenes/main.tscn"
const ACTIONS: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/"
const ENEMIES: String = "res://Source/Content/Enemies/EnemyResources/"
## TutorialManager.run_seed: every new player's first run.
const TUTORIAL_SEED: int = 21

var _run_rng_state: int = 0


func before_each() -> void:
	super()
	_run_rng_state = RNGManager.get_rng(RNGManager.Bucket.RUN).state


func after_each() -> void:
	RNGManager.get_rng(RNGManager.Bucket.RUN).state = _run_rng_state
	super()


## A GameStateManager with main.tscn's encounter lists, out of the tree.
func _main_state_manager() -> GameStateManager:
	var state: SceneState = (load(MAIN_SCENE) as PackedScene).get_state()
	var manager: GameStateManager = autofree(GameStateManager.new())
	for node: int in state.get_node_count():
		if state.get_node_name(node) != &"GameStateManager":
			continue
		for prop: int in state.get_node_property_count(node):
			var prop_name: StringName = state.get_node_property_name(node, prop)
			if prop_name != &"script":
				manager.set(prop_name, state.get_node_property_value(node, prop))
	manager.current_game_save = manager.current_game_save.duplicate()
	manager.current_game_save.sector_scenarios = []
	return manager


func _roll_sector(manager: GameStateManager, run_seed: int, sector_index: int) -> Array[ScenarioResource]:
	RNGManager.start_new_run(run_seed)
	manager.current_game_save.sector_index = sector_index
	manager._randomize_sector_scenarios()
	return manager.current_game_save.sector_scenarios


func _has_supporting_ship(scenario: ScenarioResource) -> bool:
	for ship: EnemyStateRewardResource in scenario.starting_enemies:
		if ship.enemy_resource and ship.enemy_resource.supports_allies():
			return true
	return false


# ── Read off the actions ─────────────────────────────────────────────────────

func test_actions_that_help_an_ally_are_read_as_assists() -> void:
	for action_name: String in ["aegis_ally", "repair_ally", "relay", "holo_loader"]:
		var action: EnemyActionResource = load(ACTIONS + action_name + ".tres")
		assert_true(action.assists_ally(), action_name)


func test_actions_that_dont_help_an_ally_are_not() -> void:
	for action_name: String in ["attack_player", "shield_self", "raid", "purge_vents", "launch_interceptor"]:
		var action: EnemyActionResource = load(ACTIONS + action_name + ".tres")
		assert_false(action.assists_ally(), action_name)


func test_the_field_tender_waits_for_sector_two() -> void:
	var tender: EnemyResource = load(ENEMIES + "tender.tres")
	assert_true(tender.supports_allies())
	assert_eq(tender.earliest_sector(), 1)


func test_a_ship_that_only_fights_can_be_met_from_the_start() -> void:
	var fighter: EnemyResource = load(ENEMIES + "attacker.tres")
	assert_false(fighter.supports_allies())
	assert_eq(fighter.earliest_sector(), 0)


func test_an_encounter_waits_for_its_latest_ship() -> void:
	var escort: ScenarioResource = load(
		"res://Source/Content/ScenarioResources/Scenarios/COMBAT_TenderEscort/COMBAT_tender_escort.tres"
	)
	var pool: Array[ScenarioResource] = [escort]
	assert_eq(escort.earliest_sector(), 1)
	assert_eq(ScenarioResource.allowed_in_sector(pool, 0).size(), 0)
	assert_eq(ScenarioResource.allowed_in_sector(pool, 1).size(), 1)


# ── Dealt into a sector ──────────────────────────────────────────────────────

func test_sector_one_never_deals_a_ship_that_helps_its_allies() -> void:
	var manager: GameStateManager = _main_state_manager()
	for run_seed: int in [TUTORIAL_SEED, 1, 2, 3, 4, 5, 6, 7, 8, 9]:
		for scenario: ScenarioResource in _roll_sector(manager, run_seed, 0):
			assert_false(_has_supporting_ship(scenario),
				"seed %d dealt %s into sector 1" % [run_seed, scenario.resource_path.get_file()])


func test_sector_two_can_deal_them() -> void:
	var manager: GameStateManager = _main_state_manager()
	var dealt: bool = false
	for run_seed: int in range(1, 30):
		for scenario: ScenarioResource in _roll_sector(manager, run_seed, 1):
			dealt = dealt or _has_supporting_ship(scenario)
	assert_true(dealt, "support ships still turn up once the player has learned the ropes")


func test_the_gate_keeps_a_seeded_maps_layout() -> void:
	# Lists are filtered before anything is drawn, so a seed still lays out
	# the same shops, elites and arrival; only who is in each fight changes.
	var manager: GameStateManager = _main_state_manager()
	var sector: Array[ScenarioResource] = _roll_sector(manager, TUTORIAL_SEED, 0)
	var arrival: int = manager.current_game_save.current_scenario_index
	assert_eq(sector[arrival], manager.starting_scenario)
	assert_true(sector[arrival + 1] == manager.shop_scenario,
		"the tutorial promises a shop beside the opening fight")
	for distance: int in [4, 5, 6]:
		assert_true(sector[arrival + distance] in manager.combat_scenarios,
			"and an ordinary fight %d to the right" % distance)


# ── A run's first stops are free of place rules ──────────────────────────────

const BASIC_BACKGROUNDS: String = "res://Source/Resources/BackgroundResources/RandomBackgroundResources/all_basic_backgrounds.tres"


func test_a_rule_free_draw_never_lands_under_a_rule() -> void:
	var pool: RandomBackgroundResource = load(BASIC_BACKGROUNDS)
	var rng := RandomNumberGenerator.new()
	for i: int in range(200):
		rng.seed = i
		assert_null(pool.get_random_background(rng, true).global_modifier)


func test_an_ordinary_draw_still_can() -> void:
	var pool: RandomBackgroundResource = load(BASIC_BACKGROUNDS)
	var rng := RandomNumberGenerator.new()
	var ruled: bool = false
	for i: int in range(200):
		rng.seed = i
		ruled = ruled or pool.get_random_background(rng).global_modifier != null
	assert_true(ruled)


func test_a_rule_free_draw_is_still_one_draw() -> void:
	var pool: RandomBackgroundResource = load(BASIC_BACKGROUNDS)
	var plain := RandomNumberGenerator.new()
	var calm := RandomNumberGenerator.new()
	plain.seed = 7
	calm.seed = 7
	pool.get_random_background(plain)
	pool.get_random_background(calm, true)
	assert_eq(calm.state, plain.state, "the stream after the pick is unchanged")


func test_a_pool_with_only_ruled_backgrounds_draws_as_usual() -> void:
	var pool := RandomBackgroundResource.new()
	pool.eligible_backgrounds = [load("res://Source/Resources/BackgroundResources/pulsar_field.tres")]
	assert_not_null(pool.get_random_background(RandomNumberGenerator.new(), true))


func test_slots_within_a_jump_of_the_arrival_are_rule_free() -> void:
	var manager: GameStateManager = _main_state_manager()
	_roll_sector(manager, TUTORIAL_SEED, 0)
	var arrival: int = manager.current_game_save.arrival_index
	assert_eq(arrival, manager.current_game_save.current_scenario_index)
	for distance: int in range(-6, 7):
		assert_true(manager.is_rule_free_slot(arrival + distance), "%+d" % distance)
	assert_false(manager.is_rule_free_slot(arrival + 7))
	# The slot is emptied once the player leaves it; the record isn't.
	manager.current_game_save.current_scenario_index = arrival + 4
	assert_true(manager.is_rule_free_slot(arrival + 4))


func test_later_sectors_have_no_rule_free_slots() -> void:
	var manager: GameStateManager = _main_state_manager()
	_roll_sector(manager, TUTORIAL_SEED, 1)
	assert_false(manager.is_rule_free_slot(manager.current_game_save.arrival_index))


func test_an_old_save_without_an_arrival_has_none() -> void:
	var manager: GameStateManager = _main_state_manager()
	manager.current_game_save.arrival_index = -1
	assert_false(manager.is_rule_free_slot(0))


func test_the_tutorials_first_jump_lands_rule_free() -> void:
	# The jump step promises a fight 4, 5 or 6 to the right. Drawn the way
	# BackgroundManager draws it: the slot's own seed, then the pick.
	var manager: GameStateManager = _main_state_manager()
	var sector: Array[ScenarioResource] = _roll_sector(manager, TUTORIAL_SEED, 0)
	var arrival: int = manager.current_game_save.arrival_index
	for distance: int in [4, 5, 6]:
		var slot: int = arrival + distance
		var scenario: ScenarioResource = sector[slot]
		var pool: RandomBackgroundResource = scenario.background_resource as RandomBackgroundResource
		if pool == null:
			continue
		RNGManager.seed_scenario(hash([scenario.scenario_seed, slot]))
		var background: BackgroundResource = pool.get_random_background(
			RNGManager.get_rng(RNGManager.Bucket.BACKGROUND), manager.is_rule_free_slot(slot)
		)
		assert_null(background.global_modifier, "%s at +%d" % [scenario.resource_path.get_file(), distance])
