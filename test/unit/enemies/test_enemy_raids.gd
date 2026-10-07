extends "res://test/helpers/die_fighter_test.gd"
## Ships fighting each other: a pirate's Raid on a civilian, who gets credit
## for a kill one ship makes on another, and how the scenario hears about it.

const Ships := preload("res://test/helpers/ships.gd")
const Faction := ScenarioManager.Faction
const RAID := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/raid.tres"
const RAIDER := "res://Source/Content/Enemies/EnemyResources/raider.tres"
const EVENT_DIR := "res://Source/Content/ScenarioResources/Scenarios/EVENT_PiratesAttackingCivilian/"


func before_each() -> void:
	super()
	RNGManager.seed_scenario(77)


func _ship(faction: Faction) -> Enemy:
	var made: Enemy = Ships.ship(faction)
	autofree(made.health)
	return autofree(made)


# ── The Raid action ────────────────────────────────────────────────────────────

func test_a_raid_binds_prey_and_never_threatens_the_player() -> void:
	var raid: EnemyActionResource = load(RAID)
	assert_eq(raid.get_binding(), EnemyActionResource.Binding.HOSTILE_SHIP)
	assert_eq(raid.get_threat(), EnemyActionResource.Threat.NEUTRAL,
		"its damage lands on a civilian, so the die is no danger to the player")
	assert_true(raid.is_safe_while_hidden())


func test_damage_aimed_at_the_player_after_a_raid_step_is_dangerous_again() -> void:
	var effects: Array[EffectData] = [
		Effects.data(EffectEnums.Category.TARGETING, EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP),
		Effects.damage(),
		Effects.data(EffectEnums.Category.TARGETING, EffectEnums.TargetingSubtype.TARGET_PLAYER),
		Effects.damage(),
	]
	assert_eq(Ships.action("Both", effects).get_threat(), EnemyActionResource.Threat.DANGEROUS)


func test_the_raider_only_raids_when_there_is_someone_to_raid() -> void:
	var raider: EnemyResource = load(RAIDER)
	var pirate := _ship(Faction.PIRATE)
	var civilian := _ship(Faction.CIVILIAN)
	var with_prey := EnemyActionSituation.for_ship(pirate, Ships.roster([pirate, civilian]))
	var without := EnemyActionSituation.for_ship(pirate, Ships.roster([pirate, _ship(Faction.PIRATE)]))

	var raids_with_prey: int = 0
	for pool: EnemyTurnActionList in raider.action_options:
		for i: int in range(40):
			for action: EnemyActionResource in EnemyActionSelector.roll(pool, with_prey):
				if action.name == "Raid":
					raids_with_prey += 1
			for action: EnemyActionResource in EnemyActionSelector.roll(pool, without):
				assert_ne(action.name, "Raid")
	assert_gt(raids_with_prey, 0)


# ── Whose kill it was ──────────────────────────────────────────────────────────

func test_a_ship_finished_by_another_ship_is_not_the_players_kill() -> void:
	var pirate := _ship(Faction.PIRATE)
	var civilian := _ship(Faction.CIVILIAN)
	assert_false(civilian.was_killed_by_ship(), "untouched")
	civilian.last_damaged_by = pirate
	assert_true(civilian.was_killed_by_ship())
	civilian.last_damaged_by = make_player()
	assert_false(civilian.was_killed_by_ship())
	civilian.last_damaged_by = civilian
	assert_false(civilian.was_killed_by_ship(), "its own recoil is no one else's kill")


# ── What the scenario hears ────────────────────────────────────────────────────

func test_the_new_scenario_event_was_appended() -> void:
	# Authored transition dictionaries store these as raw ints.
	assert_eq(ScenarioManager.ScenarioEvent.PIRATE_ATTACKED_CIVILIAN, 9)


func test_pirates_firing_on_civilians_is_a_scenario_event() -> void:
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	watch_signals(Events)
	manager._handle_ship_attack(_ship(Faction.PIRATE), _ship(Faction.CIVILIAN))
	assert_signal_emitted_with_parameters(Events, "scenario_event",
		[ScenarioManager.ScenarioEvent.PIRATE_ATTACKED_CIVILIAN])


func test_other_ship_fights_are_not() -> void:
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	watch_signals(Events)
	manager._handle_ship_attack(_ship(Faction.CIVILIAN), _ship(Faction.PIRATE))
	manager._handle_ship_attack(_ship(Faction.PIRATE), _ship(Faction.PIRATE))
	assert_signal_not_emitted(Events, "scenario_event")


func test_the_event_reacts_to_a_raid() -> void:
	var distress: ScenarioShipState = load(EVENT_DIR + "civilian_distress.tres")
	var warning: ScenarioShipState = load(EVENT_DIR + "pirate_warning.tres")
	var raid_event := ScenarioManager.ScenarioEvent.PIRATE_ATTACKED_CIVILIAN
	assert_eq(distress.handle_scenario_event(raid_event).resource_path, EVENT_DIR + "civilian_under_fire.tres")
	var hopeful: ScenarioShipState = load(EVENT_DIR + "civilian_hopeful.tres")
	assert_eq(hopeful.handle_scenario_event(raid_event).resource_path, EVENT_DIR + "civilian_under_fire.tres",
		"a raid lands mid-fight too, after the player has stepped in")
	var raiding: ScenarioShipState = warning.handle_scenario_event(raid_event)
	assert_eq(raiding.resource_path, EVENT_DIR + "pirate_raiding.tres")
	assert_eq(raiding.handle_scenario_event(ScenarioManager.ScenarioEvent.CIVILIANS_DEFEATED).resource_path,
		EVENT_DIR + "pirate_satisfied.tres", "a pirate that made the kill doesn't thank the player for it")
