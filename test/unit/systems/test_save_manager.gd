extends "res://test/helpers/die_fighter_test.gd"
## SaveManager: a written save reads back as the same run, and saves it can't
## trust are refused rather than half-loaded.
##
## Uses its own SaveManager instance pointed at a scratch file, never the
## autoload or the player's real save.

const SaveManagerScript: GDScript = preload("res://Source/Systems/Autoloads/save_manager.gd")
const TEST_SAVE_PATH: String = "user://test_save_game.json"
const TILE_PATH: String = "res://Source/Content/Tiles/TileResources/amplifier.tres"
const SCENARIO_PATH: String = "res://Source/Content/ScenarioResources/Scenarios/COMBAT_DroneBattery/COMBAT_drone_battery.tres"

var saves: Node


func before_each() -> void:
	super()
	saves = autofree(SaveManagerScript.new())
	saves.save_path = TEST_SAVE_PATH
	saves.delete_save()


func after_each() -> void:
	saves.delete_save()
	super()


func _write_raw(payload: Variant) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(payload if payload is String else JSON.stringify(payload))
	file.close()


func _sample_save() -> GameSaveResource:
	var save := GameSaveResource.new()
	save.player_health = 17
	save.player_max_health = 30
	save.player_defense = 2
	save.player_engine_charge = 9
	save.num_of_dice = 5
	save.money = 42
	save.current_scenario_index = 3
	save.sector_index = 1

	var scenario: ScenarioResource = load(SCENARIO_PATH)
	scenario.scenario_seed = 123456
	save.sector_scenarios = [scenario]

	var tile_locations: Dictionary[Vector2i, TileResource] = {Vector2i(2, 1): load(TILE_PATH)}
	save.tile_locations = tile_locations
	save.tile_effect_data = {Vector2i(2, 1): {"charge": 3}}
	save.map_state = {"fate_index": 4}
	save.run_stats = {"ships_destroyed": 6}
	save.rng_states = {"RUN": "9007199254740993"}
	save.scenario_progress = {"cleared": true}
	return save


func test_nothing_saved_reads_as_null() -> void:
	assert_false(saves.has_save())
	assert_null(saves.read_save())


func test_a_save_round_trips() -> void:
	watch_signals(Events)
	saves.write_save(_sample_save())
	assert_signal_emitted(Events, "game_saved")
	assert_true(saves.has_save())

	var loaded: GameSaveResource = saves.read_save()
	assert_not_null(loaded)
	assert_eq(loaded.player_health, 17)
	assert_eq(loaded.player_max_health, 30)
	assert_eq(loaded.player_engine_charge, 9)
	assert_eq(loaded.num_of_dice, 5)
	assert_eq(loaded.money, 42)
	assert_eq(loaded.current_scenario_index, 3)
	assert_eq(loaded.sector_index, 1)

	assert_eq(loaded.sector_scenarios.size(), 1)
	assert_eq(loaded.sector_scenarios[0].resource_path, SCENARIO_PATH)
	assert_eq(loaded.sector_scenarios[0].scenario_seed, 123456)

	assert_eq(loaded.tile_locations.keys(), [Vector2i(2, 1)])
	assert_eq(loaded.tile_locations[Vector2i(2, 1)].resource_path, TILE_PATH)
	assert_eq(loaded.tile_effect_data[Vector2i(2, 1)], {"charge": 3})


func test_numbers_come_back_as_ints_not_json_floats() -> void:
	saves.write_save(_sample_save())
	var loaded: GameSaveResource = saves.read_save()
	assert_typeof(loaded.map_state["fate_index"], TYPE_INT)
	assert_typeof(loaded.run_stats["ships_destroyed"], TYPE_INT)
	assert_typeof(loaded.tile_effect_data[Vector2i(2, 1)]["charge"], TYPE_INT)


func test_rng_states_keep_full_int64_precision() -> void:
	saves.write_save(_sample_save())
	assert_eq(saves.read_save().rng_states["RUN"], "9007199254740993")


func test_delete_save() -> void:
	saves.write_save(_sample_save())
	saves.delete_save()
	assert_false(saves.has_save())


func test_a_corrupt_file_is_ignored() -> void:
	_write_raw("{ this is not json")
	assert_null(saves.read_save())
	assert_push_warning("corrupt")
	assert_engine_error_count(1, "Godot's JSON parser reports the bad file itself")


func test_a_save_from_a_newer_build_is_refused() -> void:
	_write_raw({"version": SaveManagerScript.SAVE_VERSION + 1})
	assert_null(saves.read_save())
	assert_push_warning("unsupported save version")


func test_a_version_1_save_still_loads() -> void:
	_write_raw({
		"version": 1,
		"sector_scenarios": [{"id": "COMBAT_drone_battery", "seed": 5}],
	})
	var loaded: GameSaveResource = saves.read_save()
	assert_not_null(loaded)
	assert_eq(loaded.map_state, {}, "missing run-state fields load empty")


func test_a_save_with_no_known_scenarios_is_refused() -> void:
	_write_raw({"version": SaveManagerScript.SAVE_VERSION, "sector_scenarios": []})
	assert_null(saves.read_save())
	assert_push_warning("no valid scenarios")
