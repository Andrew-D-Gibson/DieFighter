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
