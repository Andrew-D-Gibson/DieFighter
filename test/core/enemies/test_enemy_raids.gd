extends "res://test/helpers/die_fighter_test.gd"
## Ships fighting each other: a Raid, which hits another ship and hands it
## the die; why a ship on the player's side always has one; who gets credit
## for a kill one ship makes on another, and how the scenario hears about it.

const Ships := preload("res://test/helpers/ships.gd")
const Faction := ScenarioManager.Faction
const RAID := "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/raid.tres"
const VENOM_FIGHTER := "res://Source/Content/Enemies/EnemyResources/attacker.tres"
const EVENT_DIR := "res://Source/Content/ScenarioResources/Scenarios/EVENT_PiratesAttackingCivilian/"


func before_each() -> void:
	super()
	RNGManager.seed_scenario(77)


func _ship(faction: Faction, attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE) -> Enemy:
	var made: Enemy = Ships.ship(faction, 10, 10, attitude)
	autofree(made.health)
	return autofree(made)


func _raid() -> EnemyActionResource:
	return (load(RAID) as EnemyActionResource).duplicate(true)


func _raids_in(actions: Array[EnemyActionResource]) -> int:
	return actions.filter(func(action: EnemyActionResource) -> bool: return action.hands_off_to_hostile()).size()


# ── The Raid action ────────────────────────────────────────────────────────────

func test_a_raid_binds_prey_and_never_threatens_the_player_itself() -> void:
	var raid: EnemyActionResource = load(RAID)
	assert_eq(raid.get_binding(), EnemyActionResource.Binding.HOSTILE_SHIP)
	assert_eq(raid.get_threat(), EnemyActionResource.Threat.NEUTRAL,
		"its damage lands on another ship, so the step itself is no danger to the player")
	assert_true(raid.is_safe_while_hidden())


func test_a_raid_hands_its_die_to_its_prey() -> void:
	var raid: EnemyActionResource = load(RAID)
	assert_eq(raid.get_relay(), EnemyActionResource.Relay.FEED)
	assert_true(raid.hands_off_to_hostile())
	assert_eq(raid.relay_face(4), 4, "the prey spends it on the same face")
	assert_false(Ships.relay().hands_off_to_hostile(), "a Relay feeds an ally")
	assert_eq(Ships.relay().get_binding(), EnemyActionResource.Binding.ALLY)


func test_a_raid_reads_as_the_threat_of_what_its_prey_does_with_the_die() -> void:
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var pirate := _ship(Faction.PIRATE)
	var raids: Array[EnemyActionResource] = []
	var attacks: Array[EnemyActionResource] = []
	for i: int in range(6):
		raids.append(_raid())
		attacks.append(Ships.attack())
	Ships.set_table(civilian, raids)
	Ships.set_table(pirate, attacks)
	civilian.turn_actions[2].bound_target = pirate
	assert_eq(civilian.threat_of_face(3), EnemyActionResource.Threat.DANGEROUS,
		"the pirate fires the die at the player")


func test_damage_aimed_at_the_player_after_a_raid_step_is_dangerous_again() -> void:
	var effects: Array[EffectData] = [
		Effects.data(EffectEnums.Category.TARGETING, EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP),
		Effects.damage(),
		Effects.data(EffectEnums.Category.TARGETING, EffectEnums.TargetingSubtype.TARGET_PLAYER),
		Effects.damage(),
	]
	assert_eq(Ships.action("Both", effects).get_threat(), EnemyActionResource.Threat.DANGEROUS)

# ── Ships on the player's side always hand off ─────────────────────────────────

func test_a_ship_on_the_players_side_owes_a_hand_off_only_while_its_foe_fights_the_player() -> void:
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var fighting := _ship(Faction.PIRATE)
	var idle := _ship(Faction.PIRATE, Enemy.Attitude.NEUTRAL)
	assert_true(EnemyActionSituation.for_ship(civilian, Ships.roster([civilian, fighting])).owes_hand_off)
	assert_false(EnemyActionSituation.for_ship(civilian, Ships.roster([civilian, idle])).owes_hand_off,
		"nobody is fighting the player")
	assert_false(EnemyActionSituation.for_ship(fighting, Ships.roster([civilian, fighting])).owes_hand_off,
		"a ship fighting the player owes it nothing")
	var turned := _ship(Faction.CIVILIAN)
	assert_true(EnemyActionSituation.for_ship(idle, Ships.roster([idle, turned])).owes_hand_off,
		"a pirate standing by while the player fights a civilian is on the player's side too")


func test_a_ship_that_owes_a_hand_off_always_rolls_one() -> void:
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var pirate := _ship(Faction.PIRATE)
	var options: Array[EnemyActionOptionResource] = [
		Ships.option(Ships.idle(), 1.0, 1, 1), Ships.option(load(RAID), 0.0, 1, 1),
	]
	var pool := Ships.pool(options)
	var situation := EnemyActionSituation.for_ship(civilian, Ships.roster([civilian, pirate]))
	for run: int in range(40):
		RNGManager.seed_scenario(run)
		assert_eq(_raids_in(EnemyActionSelector.roll(pool, situation)), 1,
			"weighted out, it still turns up exactly once (seed %d)" % run)


func test_the_hand_off_survives_the_variety_cap() -> void:
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var pirate := _ship(Faction.PIRATE)
	var options: Array[EnemyActionOptionResource] = [
		Ships.option(Ships.attack(), 5.0, 1, 1), Ships.option(load(RAID), 0.01, 1, 1),
	]
	var situation := EnemyActionSituation.for_ship(civilian, Ships.roster([civilian, pirate]))
	situation.max_action_kinds = 1
	for run: int in range(20):
		RNGManager.seed_scenario(run)
		assert_gt(_raids_in(EnemyActionSelector.roll(Ships.pool(options), situation)), 0)


func test_a_ship_that_owes_nothing_rolls_as_it_always_did() -> void:
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var idle := _ship(Faction.PIRATE, Enemy.Attitude.NEUTRAL)
	var options: Array[EnemyActionOptionResource] = [
		Ships.option(Ships.idle(), 1.0, 1, 1), Ships.option(load(RAID), 0.0, 1, 1),
	]
	var situation := EnemyActionSituation.for_ship(civilian, Ships.roster([civilian, idle]))
	for run: int in range(20):
		RNGManager.seed_scenario(run)
		assert_eq(_raids_in(EnemyActionSelector.roll(Ships.pool(options), situation)), 0)


func test_raids_on_each_other_keep_the_player_sides_and_reroll_the_enemys() -> void:
	# Each hands the die to the other on the same face: a loop. The civilian
	# owes its Raid, so the pirate's is the one that gives way, even though
	# the pirate comes first in the formation.
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var pirate := _ship(Faction.PIRATE)
	var attack_only: Array[EnemyActionOptionResource] = [Ships.option(Ships.attack())]
	Ships.give_pool(pirate, attack_only)
	Ships.give_pool(civilian, attack_only)
	var pirate_raids: Array[EnemyActionResource] = []
	var civilian_raids: Array[EnemyActionResource] = []
	for i: int in range(6):
		pirate_raids.append(_raid())
		civilian_raids.append(_raid())
	Ships.set_table(pirate, pirate_raids)
	Ships.set_table(civilian, civilian_raids)
	var roster := Ships.roster([pirate, civilian])
	EnemyTargetBinder.bind(roster, roster)
	for slot: int in range(6):
		assert_true(civilian.turn_actions[slot].hands_off_to_hostile(), "civilian face %d kept" % (slot + 1))
		assert_eq(civilian.turn_actions[slot].bound_target, pirate)
		assert_false(pirate.turn_actions[slot].hands_off_to_hostile(), "pirate face %d gave way" % (slot + 1))


func test_a_ship_on_the_players_side_raids_whoever_is_fighting_the_player() -> void:
	var civilian := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	var idle := _ship(Faction.PIRATE, Enemy.Attitude.NEUTRAL)
	var fighting := _ship(Faction.PIRATE)
	var roster := Ships.roster([civilian, idle, fighting])
	for run: int in range(20):
		RNGManager.seed_scenario(run)
		var raids: Array[EnemyActionResource] = []
		for i: int in range(6):
			raids.append(_raid())
		Ships.set_table(civilian, raids)
		EnemyTargetBinder.bind(Ships.roster([civilian]), roster)
		assert_eq(civilian.turn_actions[0].bound_target, fighting)


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


# ── Ships on the player's side never attack the player ─────────────────────────

func test_a_ship_on_the_players_side_never_rolls_or_plays_an_attack_on_the_player() -> void:
	var options: Array[EnemyActionOptionResource] = [Ships.option(Ships.attack()), Ships.option(Ships.idle())]
	for attitude: Enemy.Attitude in [Enemy.Attitude.FRIENDLY, Enemy.Attitude.NEUTRAL]:
		var ship := _ship(Faction.CIVILIAN, attitude)
		var situation := EnemyActionSituation.for_ship(ship, Ships.roster([ship]))
		for run: int in range(20):
			RNGManager.seed_scenario(run)
			for rolled: EnemyActionResource in EnemyActionSelector.roll(Ships.pool(options), situation):
				assert_false(rolled.hurts_player(), "attitude %d rolled an attack" % attitude)
	# A table rolled while it was hostile still can't fire once it has turned.
	var turned := _ship(Faction.CIVILIAN, Enemy.Attitude.FRIENDLY)
	assert_eq(Ships.attack().get_outcome(turned), EnemyActionResource.Outcome.BLOCKED)
	assert_eq(Ships.attack().get_outcome(_ship(Faction.PIRATE)), EnemyActionResource.Outcome.ACTS)
