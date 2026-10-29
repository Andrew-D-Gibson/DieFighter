class_name AutoPilotGauntlet
extends RefCounted
## One cell of a gauntlet: a chosen scenario, played with a chosen loadout.
## tools/autoplay.sh --gauntlet runs every scenario × loadout × seed in a
## spec file, so loadouts can be compared on the same draws.
##
## The run starts the way Continue does, from a save, but one holding only the
## loadout: no sector, so GameStateManager generates an ordinary one around
## it, from the run seed. The chosen scenario then takes the starting slot,
## keeping that slot's seed, just before it loads. Everything else about the
## run (the map, the RNG, the sector's difficulty) is as a real run has it.
##
## A spec is JSON:
##   {
##     "seeds": 20,                         # runs per scenario × loadout
##     "sector": 0,                         # default sector (0 is the first)
##     "scenarios": ["COMBAT_cutpurse", {"id": "GATE_bastion", "sector": 2}],
##     "loadouts": {
##       "starter": {"tiles": {"0,1": "damage", "1,1": "bump", "2,1": "shield"}},
##       "tanky": {"tiles": {...}, "dice": 4, "hull": 40, "max_hull": 40,
##                 "money": 0, "charge": 0}
##     }
##   }
## Scenario and tile ids are ContentRegistry's: the .tres file's base name.
## Tiles are placed by "x,y" grid cell, which must be one of the flown ship's
## cells. Unset loadout fields default to a new run in that ship. There's no starting shields field: arriving in a
## scenario clears shields.

var scenario_id: String
var loadout_name: String
var sector: int = 0
## The spec file, so a replay of this run can find the loadout again.
var spec_path: String = ""
var _loadout: Dictionary = {}


## Reads the cell [param scenario] × [param loadout] from the spec at
## [param path]. [param sector_override] (-1 for none) wins over the spec's.
## Returns the reason it can't be played, or "" if it can.
func load_cell(path: String, scenario: String, loadout: String, sector_override: int) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "can't read gauntlet spec %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	var spec: Variant = JSON.parse_string(text)
	if spec is not Dictionary:
		return "gauntlet spec %s isn't a JSON object" % path

	var loadouts: Dictionary = (spec as Dictionary).get("loadouts", {})
	if not loadouts.has(loadout):
		return "gauntlet spec has no loadout '%s'" % loadout
	if ContentRegistry.get_scenario_path(scenario) == "":
		return "no scenario '%s'" % scenario
	scenario_id = scenario
	loadout_name = loadout
	spec_path = path
	_loadout = loadouts[loadout]

	sector = int((spec as Dictionary).get("sector", 0))
	for entry: Variant in (spec as Dictionary).get("scenarios", []):
		if entry is Dictionary and (entry as Dictionary).get("id", "") == scenario:
			sector = int((entry as Dictionary).get("sector", sector))
	if sector_override >= 0:
		sector = sector_override

	var cells: Array[Vector2i] = Globals.current_ship().get_cells()
	for cell: String in (_loadout.get("tiles", {}) as Dictionary):
		if _cell(cell) == Vector2i(-1, -1):
			return "loadout '%s' has a bad cell '%s' (want \"x,y\")" % [loadout, cell]
		if _cell(cell) not in cells:
			return "loadout '%s' puts a tile at %s, which %s doesn't have" % [loadout, cell, Globals.current_ship().id]
		if ContentRegistry.get_tile_path(str(_loadout["tiles"][cell])) == "":
			return "loadout '%s' has no tile '%s'" % [loadout, _loadout["tiles"][cell]]
	return ""


## The save the run starts from: the loadout and the sector, and no
## scenarios, so the sector is generated.
func build_save() -> GameSaveResource:
	var start: GameSaveResource = ShipCatalog.starting_save(Globals.current_ship())
	var game_save: GameSaveResource = GameSaveResource.new()
	game_save.ship_id = start.ship_id
	game_save.player_max_health = int(_loadout.get("max_hull", start.player_max_health))
	game_save.player_health = int(_loadout.get("hull", game_save.player_max_health))
	game_save.player_engine_charge = int(_loadout.get("charge", 0))
	game_save.num_of_dice = int(_loadout.get("dice", start.num_of_dice))
	game_save.money = int(_loadout.get("money", 0))
	game_save.sector_index = sector

	var tiles: Dictionary[Vector2i, TileResource] = {}
	if _loadout.has("tiles"):
		for cell: String in (_loadout["tiles"] as Dictionary):
			tiles[_cell(cell)] = load(ContentRegistry.get_tile_path(str(_loadout["tiles"][cell])))
	else:
		tiles = start.tile_locations.duplicate()
	game_save.tile_locations = tiles
	game_save.unlocked_cells = start.unlocked_cells.duplicate()
	return game_save


## Puts the gauntlet's scenario in the starting slot of the sector just
## generated, with that slot's seed. Called from Events.load_game_save, which
## comes before the opening scenario loads and before the map is drawn.
func place_scenario(game_save: GameSaveResource) -> void:
	var slot: int = game_save.current_scenario_index
	var scenario: ScenarioResource = load(ContentRegistry.get_scenario_path(scenario_id))
	scenario.scenario_seed = game_save.sector_scenarios[slot].scenario_seed
	game_save.sector_scenarios[slot] = scenario


## For the transcript header.
func describe() -> Dictionary:
	return {"scenario": scenario_id, "loadout": loadout_name, "sector": sector, "spec": spec_path}


static func _cell(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split(",")
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))
