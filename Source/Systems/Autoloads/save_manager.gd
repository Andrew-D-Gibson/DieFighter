extends Node

## Reads/writes the single autosave slot to disk as JSON. Owns no live game
## state itself — GameStateManager is responsible for keeping a
## GameSaveResource up to date and calling write_save() at checkpoints.

const SAVE_PATH: String = "user://save_game.json"
const SAVE_VERSION: int = 2

## Oldest format read_save() still accepts. Version 1 predates the run-state
## fields; those load as empty and each system falls back to its old behaviour.
const _MIN_READABLE_VERSION: int = 1


func _ready() -> void:
	# A run ends either way — a finished save is not a resumable one.
	Events.game_over.connect(delete_save)
	Events.victory.connect(delete_save)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func write_save(game_save: GameSaveResource) -> void:
	var sector_scenarios_data: Array = []
	for scenario: ScenarioResource in game_save.sector_scenarios:
		var id: String = ContentRegistry.get_scenario_id(scenario.resource_path)
		if id == "":
			continue
		sector_scenarios_data.append({"id": id, "seed": scenario.scenario_seed})

	var tile_locations_data: Array = []
	for pos: Vector2i in game_save.tile_locations:
		var tile_resource: TileResource = game_save.tile_locations[pos]
		var id: String = ContentRegistry.get_tile_id(tile_resource.resource_path)
		if id == "":
			continue
		var entry: Dictionary = {"x": pos.x, "y": pos.y, "id": id}
		if game_save.tile_effect_data.has(pos):
			entry["data"] = game_save.tile_effect_data[pos]
		tile_locations_data.append(entry)

	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"player_health": game_save.player_health,
		"player_max_health": game_save.player_max_health,
		"player_defense": game_save.player_defense,
		"player_engine_charge": game_save.player_engine_charge,
		"num_of_dice": game_save.num_of_dice,
		"money": game_save.money,
		"current_scenario_index": game_save.current_scenario_index,
		"sector_index": game_save.sector_index,
		"sector_scenarios": sector_scenarios_data,
		"tile_locations": tile_locations_data,
		"map_state": game_save.map_state,
		"run_stats": game_save.run_stats,
		"rng_states": game_save.rng_states,
		"scenario_progress": game_save.scenario_progress,
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: failed to open save file for writing")
		return
	file.store_string(JSON.stringify(payload, "\t"))

	Events.game_saved.emit()


func read_save() -> GameSaveResource:
	if not has_save():
		return null

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: failed to open save file for reading")
		return null

	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_warning("SaveManager: save file is corrupt, ignoring")
		return null

	var version: int = int(data.get("version", -1))
	if version < _MIN_READABLE_VERSION or version > SAVE_VERSION:
		push_warning("SaveManager: unsupported save version %d, ignoring" % version)
		return null

	var game_save: GameSaveResource = GameSaveResource.new()
	game_save.player_health = int(data.get("player_health", 0))
	game_save.player_max_health = int(data.get("player_max_health", 0))
	game_save.player_defense = int(data.get("player_defense", 0))
	game_save.player_engine_charge = int(data.get("player_engine_charge", 0))
	game_save.num_of_dice = int(data.get("num_of_dice", 0))
	game_save.money = int(data.get("money", 0))
	game_save.current_scenario_index = int(data.get("current_scenario_index", 0))
	game_save.sector_index = int(data.get("sector_index", 0))

	var sector_scenarios: Array[ScenarioResource] = []
	for entry: Variant in data.get("sector_scenarios", []):
		var path: String = ContentRegistry.get_scenario_path(entry["id"])
		if path == "":
			continue
		var scenario: ScenarioResource = ResourceLoader.load(path)
		scenario.scenario_seed = int(entry["seed"])
		sector_scenarios.append(scenario)
	game_save.sector_scenarios = sector_scenarios

	var tile_locations: Dictionary[Vector2i, TileResource] = {}
	var tile_effect_data: Dictionary = {}
	for entry: Variant in data.get("tile_locations", []):
		var path: String = ContentRegistry.get_tile_path(entry["id"])
		if path == "":
			continue
		var tile_resource: TileResource = ResourceLoader.load(path)
		var pos := Vector2i(int(entry["x"]), int(entry["y"]))
		tile_locations[pos] = tile_resource
		if entry.has("data"):
			tile_effect_data[pos] = _ints(entry["data"])
	game_save.tile_locations = tile_locations
	game_save.tile_effect_data = tile_effect_data

	game_save.map_state = _ints(data.get("map_state", {}))
	game_save.run_stats = _ints(data.get("run_stats", {}))
	game_save.rng_states = data.get("rng_states", {})
	game_save.scenario_progress = data.get("scenario_progress", {})

	if sector_scenarios.is_empty():
		push_warning("SaveManager: save file has no valid scenarios, ignoring")
		return null

	return game_save


## JSON has one number type, so every int comes back a float. Converts a flat
## dictionary of numbers back to ints.
static func _ints(dict: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in dict:
		out[key] = int(dict[key])
	return out
