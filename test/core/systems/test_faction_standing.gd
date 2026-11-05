extends "res://test/helpers/die_fighter_test.gd"
## Faction memory: what the run remembers of the player (FactionLedger), how
## it's recorded (FactionDeed), and the rules content reads it by (standing
## branches, encounter requirements, consequences). Fixtures are built here;
## no shipped faction's numbers are asserted.

const SaveManagerScript: GDScript = preload("res://Source/Systems/Autoloads/save_manager.gd")
const TEST_SAVE_PATH: String = "user://test_faction_save.json"
const SCENARIO_PATH: String = "res://Source/Content/ScenarioResources/Scenarios/COMBAT_DroneBattery/COMBAT_drone_battery.tres"


func _faction(id: StringName) -> FactionIdentity:
	var faction: FactionIdentity = FactionIdentity.new()
	faction.id = id
	return faction


func _condition(test: FactionCondition.Test, faction: FactionIdentity = null,
		regard: FactionLedger.Regard = FactionLedger.Regard.NEUTRAL, deed: StringName = &"") -> FactionCondition:
	var condition: FactionCondition = FactionCondition.new()
	condition.test = test
	condition.faction = faction
	condition.regard = regard
	condition.deed = deed
	return condition


func _option(conditions: Array[FactionCondition], state: ScenarioShipState) -> ScenarioShipStateStandingOption:
	var option: ScenarioShipStateStandingOption = ScenarioShipStateStandingOption.new()
	option.conditions = conditions
	option.state = state
	return option


func _scenario(requirements: Array[FactionCondition] = []) -> ScenarioResource:
	var scenario: ScenarioResource = ScenarioResource.new()
	scenario.standing_requirements = requirements
	return scenario


func test_what_the_fleet_remembers_survives_a_save() -> void:
	var saves: Node = autofree(SaveManagerScript.new())
	saves.save_path = TEST_SAVE_PATH
	var ledger: FactionLedger = FactionLedger.new()
	ledger.change_standing(&"caravan", -3)
	ledger.change_standing(&"rearguard", 2)
	ledger.note_deed(&"caravan_shop_attacked")
	ledger.note_kill(&"undertow")

	var save: GameSaveResource = GameSaveResource.new()
	var scenario: ScenarioResource = load(SCENARIO_PATH)
	save.sector_scenarios = [scenario]
	save.faction_standing = ledger.get_state()
	saves.write_save(save)

	var restored: FactionLedger = FactionLedger.new()
	restored.load_state(saves.read_save().faction_standing)
	saves.delete_save()

	assert_eq(restored.standing(&"caravan"), -3)
	assert_eq(restored.standing(&"rearguard"), 2)
	assert_eq(restored.deed_count(&"caravan_shop_attacked"), 1)
	assert_eq(restored.kills(&"undertow"), 1)
	assert_typeof(restored.standing(&"caravan"), TYPE_INT, "JSON floats come back as ints")

	restored.load_state({})
	assert_eq(restored.standing(&"caravan"), 0, "a save from before faction memory remembers nothing")


func test_standing_is_held_within_its_limit() -> void:
	var ledger: FactionLedger = FactionLedger.new()
	ledger.change_standing(&"caravan", -FactionLedger.STANDING_LIMIT * 3)
	assert_eq(ledger.standing(&"caravan"), -FactionLedger.STANDING_LIMIT)
	ledger.change_standing(&"caravan", 1)
	assert_eq(ledger.standing(&"caravan"), 1 - FactionLedger.STANDING_LIMIT,
		"a grudge banked past the limit doesn't take longer to mend")


func test_a_standing_branch_takes_the_first_option_that_holds() -> void:
	var own: FactionIdentity = _faction(&"caravan")
	var gossip: ScenarioShipState = ScenarioShipState.new()
	var wary: ScenarioShipState = ScenarioShipState.new()
	var usual: ScenarioShipState = ScenarioShipState.new()
	var branch: ScenarioShipStateStandingBranch = ScenarioShipStateStandingBranch.new()
	var gossip_if: Array[FactionCondition] = [_condition(FactionCondition.Test.DEED_DONE, null,
		FactionLedger.Regard.NEUTRAL, &"shop_attacked")]
	# No faction: asks about the ship's own.
	var wary_if: Array[FactionCondition] = [_condition(FactionCondition.Test.REGARD_AT_MOST, null,
		FactionLedger.Regard.DISLIKED)]
	var options: Array[ScenarioShipStateStandingOption] = [_option(gossip_if, gossip), _option(wary_if, wary)]
	branch.options = options
	branch.otherwise = usual

	var ledger: FactionLedger = FactionLedger.new()
	assert_eq(branch.pick(ledger, own), usual, "a fleet with no opinion")

	ledger.change_standing(&"rearguard", -FactionLedger.TRUSTED_AT)
	assert_eq(branch.pick(ledger, own), usual, "another faction's grudge isn't this ship's")

	ledger.change_standing(&"caravan", -FactionLedger.LIKED_AT)
	assert_eq(branch.pick(ledger, own), wary)

	ledger.note_deed(&"shop_attacked")
	assert_eq(branch.pick(ledger, own), gossip, "the first option that holds wins")


func test_a_deed_is_felt_by_the_ships_own_faction_unless_it_names_another() -> void:
	var standing: FactionStanding = autofree(FactionStanding.new())
	var own: FactionIdentity = _faction(&"rearguard")
	var robbed: FactionDeed = FactionDeed.new()
	robbed.standing = -2
	robbed.deed = &"tithe_refused"
	var felt_elsewhere: FactionDeed = FactionDeed.new()
	felt_elsewhere.faction = _faction(&"inbound")
	felt_elsewhere.standing = 3

	standing.record(robbed, own)
	standing.record(felt_elsewhere, own)

	assert_eq(standing.ledger.standing(&"rearguard"), -2)
	assert_eq(standing.ledger.standing(&"inbound"), 3)
	assert_eq(standing.ledger.deed_count(&"tithe_refused"), 1)


func test_an_encounter_is_dealt_only_while_its_standing_requirements_hold() -> void:
	var caravan: FactionIdentity = _faction(&"caravan")
	var plain: ScenarioResource = _scenario()
	var grudge: ScenarioResource = _scenario([_condition(FactionCondition.Test.REGARD_AT_MOST, caravan,
		FactionLedger.Regard.DISLIKED)])
	var pool: Array[ScenarioResource] = [plain, grudge]
	var ledger: FactionLedger = FactionLedger.new()

	assert_eq(ScenarioResource.allowed_in_sector(pool, 0, ledger), [plain] as Array[ScenarioResource])
	ledger.change_standing(&"caravan", -FactionLedger.LIKED_AT)
	assert_eq(ScenarioResource.allowed_in_sector(pool, 0, ledger), pool)


## Seed compatibility: a run that has earned no consequence deals the map its
## seed always did. One that has is answered on an ordinary stop ahead of the
## arrival, where the player can see it coming, and never on the gate.
func test_consequences_replace_only_distant_ordinary_stops() -> void:
	var ordinary: ScenarioResource = _scenario()
	var gate: ScenarioResource = _scenario()
	var reckoning: ScenarioResource = _scenario()
	var shop: ScenarioResource = _scenario()
	var sector: Array[ScenarioResource] = []
	for i: int in range(16):
		sector.append(ordinary)
	# Only ordinary stops are replaced: this one never is.
	sector[9] = shop
	sector.append(gate)
	var replaceable: Array[ScenarioResource] = [ordinary]
	var untouched: Array[ScenarioResource] = sector.duplicate()

	SectorGenerator.place_consequences(sector, 2, replaceable, [], 1, 7)
	assert_eq(sector, untouched, "nothing earned, nothing changed")

	var owed: Array[ScenarioResource] = [reckoning]
	for placement_seed: int in range(20):
		var map: Array[ScenarioResource] = untouched.duplicate()
		SectorGenerator.place_consequences(map, 2, replaceable, owed, 1, placement_seed)
		var at: int = map.find(reckoning)
		assert_eq(map.count(reckoning), 1)
		assert_gt(at, 2, "ahead of the arrival")
		assert_eq(map[9], shop, "only an ordinary stop")
		assert_eq(map.back(), gate, "never the gate")
