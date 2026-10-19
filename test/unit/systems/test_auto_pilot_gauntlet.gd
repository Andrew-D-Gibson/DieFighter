extends "res://test/helpers/die_fighter_test.gd"
## Gauntlet specs: reading a cell, the save a run starts from, and the
## scenario taking the starting slot.

const SPEC_PATH: String = "user://test_gauntlet_spec.json"

const SPEC: Dictionary = {
	"sector": 1,
	"scenarios": ["COMBAT_cutpurse", {"id": "GATE_bastion", "sector": 2}],
	"loadouts": {
		"starter": {"tiles": {"0,1": "damage", "1,1": "bump"}},
		"tanky": {"tiles": {"0,0": "shield"}, "dice": 5, "hull": 20, "max_hull": 40, "money": 7},
		"bare": {},
		"bad_cell": {"tiles": {"0;1": "damage"}},
		"bad_tile": {"tiles": {"0,1": "no_such_tile"}},
	},
}


func before_each() -> void:
	super()
	var file: FileAccess = FileAccess.open(SPEC_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(SPEC))
	file.close()


func after_each() -> void:
	DirAccess.remove_absolute(SPEC_PATH)
	super()


func _cell(scenario: String, loadout: String, sector_override: int = -1) -> AutoPilotGauntlet:
	var gauntlet: AutoPilotGauntlet = AutoPilotGauntlet.new()
	assert_eq(gauntlet.load_cell(SPEC_PATH, scenario, loadout, sector_override), "")
	return gauntlet


func test_a_loadout_becomes_the_starting_save() -> void:
	var game_save: GameSaveResource = _cell("COMBAT_cutpurse", "tanky").build_save()
	assert_eq(game_save.num_of_dice, 5)
	assert_eq(game_save.player_health, 20)
	assert_eq(game_save.player_max_health, 40)
	assert_eq(game_save.money, 7)
	assert_eq(game_save.tile_locations.size(), 1)
	assert_eq(game_save.tile_locations[Vector2i(0, 0)].resource_path.get_file(), "shield.tres")
	assert_true(game_save.sector_scenarios.is_empty(), "the sector is generated around the loadout")


func test_unset_fields_are_a_new_runs() -> void:
	var game_save: GameSaveResource = _cell("COMBAT_cutpurse", "bare").build_save()
	var start: GameSaveResource = load(AutoPilotGauntlet._RUN_START)
	assert_eq(game_save.num_of_dice, start.num_of_dice)
	assert_eq(game_save.player_health, start.player_max_health)
	assert_eq(game_save.tile_locations.size(), start.tile_locations.size(), "no tiles means the starter kit")


func test_the_sector_comes_from_the_spec_then_the_scenario_then_the_override() -> void:
	assert_eq(_cell("COMBAT_cutpurse", "starter").sector, 1)
	assert_eq(_cell("GATE_bastion", "starter").sector, 2)
	assert_eq(_cell("GATE_bastion", "starter", 0).sector, 0)
	assert_eq(_cell("COMBAT_cutpurse", "starter").build_save().sector_index, 1)


func test_bad_cells_are_refused_with_a_reason() -> void:
	var gauntlet: AutoPilotGauntlet = AutoPilotGauntlet.new()
	assert_string_contains(gauntlet.load_cell(SPEC_PATH, "COMBAT_cutpurse", "nobody", -1), "no loadout")
	assert_string_contains(gauntlet.load_cell(SPEC_PATH, "COMBAT_cutpurse", "bad_cell", -1), "bad cell")
	assert_string_contains(gauntlet.load_cell("user://missing_spec.json", "COMBAT_cutpurse", "starter", -1), "can't read")


func test_unknown_content_is_refused() -> void:
	var gauntlet: AutoPilotGauntlet = AutoPilotGauntlet.new()
	assert_string_contains(gauntlet.load_cell(SPEC_PATH, "COMBAT_cutpurse", "bad_tile", -1), "no tile")
	assert_string_contains(gauntlet.load_cell(SPEC_PATH, "NOT_A_SCENARIO", "starter", -1), "no scenario")
	assert_push_error_count(2, "ContentRegistry says what it couldn't find")


func test_the_scenario_takes_the_starting_slot_and_its_seed() -> void:
	var game_save: GameSaveResource = GameSaveResource.new()
	var empty: ScenarioResource = load(ContentRegistry.get_scenario_path("empty_scenario")).duplicate()
	var arrival: ScenarioResource = load(ContentRegistry.get_scenario_path("COMBAT_opening_ambush")).duplicate()
	arrival.scenario_seed = 4242
	game_save.sector_scenarios = [empty, arrival, empty]
	game_save.current_scenario_index = 1

	_cell("COMBAT_cutpurse", "starter").place_scenario(game_save)

	assert_eq(game_save.sector_scenarios[1].resource_path.get_file(), "COMBAT_cutpurse.tres")
	assert_eq(game_save.sector_scenarios[1].scenario_seed, 4242)
	assert_eq(game_save.sector_scenarios[0], empty, "the rest of the sector is untouched")
