extends Node

## What the player has found across every run, for the codex on the main menu:
## each tile they've had on their grid, and each enemy they've met with how
## often they've met and destroyed it. Also which region rules and hazards
## they've read the arrival card for, so the first one waits for them, and
## which tile families they've unlocked (TileUnlocks). Kept in its own file, since the run's
## save is deleted when the run ends and this has to outlive it.
##
## Only the player's own runs count. The Scenario Lab and the AutoPilot point
## SaveManager at a file of their own, and that is how they're told apart.

## Something new was found, or a count went up.
signal changed()

const COLLECTION_PATH: String = "user://collection.json"
const COLLECTION_VERSION: int = 1

## Where this instance reads and writes. Tests point it elsewhere so they never
## touch the player's real collection.
var collection_path: String = COLLECTION_PATH:
	set(value):
		collection_path = value
		load_collection()

## Tile id -> true, for every tile that has sat on the player's grid.
var _tiles: Dictionary[String, bool] = {}
## Enemy id -> {"encountered": int, "destroyed": int}.
var _enemies: Dictionary[String, Dictionary] = {}
## Region id (EnvironmentMonitor.region_id) -> true, for every rule or hazard
## whose arrival card the player has read.
var _regions: Dictionary[String, bool] = {}
## Tile family id (TileFamilyResource.id()) -> the claim that unlocked it, a
## run and sector (TileUnlocks.claim_for()). Kept so a jump replayed from a
## Continue shows the same family again instead of unlocking a second one.
var _families: Dictionary[String, String] = {}
var _write_queued: bool = false


func _ready() -> void:
	load_collection()
	# A checkpoint is written each time the grid changes hands (arrival,
	# rewards, the shop), so the tiles saved with it are the ones owned.
	Events.game_saved.connect(_record_grid)
	Events.ship_encountered.connect(_on_ship_encountered)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)


func has_tile(id: String) -> bool:
	return _tiles.has(id)


func has_enemy(id: String) -> bool:
	return _enemies.has(id)


func times_encountered(id: String) -> int:
	return int(_enemies.get(id, {}).get("encountered", 0))


func times_destroyed(id: String) -> int:
	return int(_enemies.get(id, {}).get("destroyed", 0))


func record_tile(id: String) -> void:
	if id.is_empty() or _tiles.has(id):
		return
	_tiles[id] = true
	_queue_write()


func has_read_region(id: String) -> bool:
	return _regions.has(id)


func record_region(id: String) -> void:
	if id.is_empty() or _regions.has(id):
		return
	_regions[id] = true
	_queue_write()


func record_encounter(id: String) -> void:
	_count(id, "encountered")


func record_destroyed(id: String) -> void:
	_count(id, "destroyed")


func has_family(id: String) -> bool:
	return _families.has(id)


## [param claim] marks what earned it; empty for one given outright (the dev
## console, the options menu's Unlock All).
func record_family(id: String, claim: String = "") -> void:
	if id.is_empty() or _families.has(id):
		return
	_families[id] = claim
	_queue_write()


## The family [param claim] unlocked, or "" if it hasn't unlocked one.
func family_for_claim(claim: String) -> String:
	if claim.is_empty():
		return ""
	for id: String in _families:
		if _families[id] == claim:
			return id
	return ""


## Locks every family again, for the dev console.
func clear_families() -> void:
	_families.clear()
	_queue_write()


## Forgets everything found, on disk too.
func clear() -> void:
	_tiles.clear()
	_enemies.clear()
	_regions.clear()
	_families.clear()
	changed.emit()
	_write()


## Marks every id given as found, in one write. Counts already earned are
## kept; an enemy never met counts as met once, so the codex shows it.
func unlock(tile_ids: Array[String], enemy_ids: Array[String], region_ids: Array[String]) -> void:
	for id: String in tile_ids:
		_tiles[id] = true
	for id: String in enemy_ids:
		if not _enemies.has(id):
			_enemies[id] = {"encountered": 1, "destroyed": 0}
	for id: String in region_ids:
		_regions[id] = true
	_queue_write()


## Whether what happens now is the player's own run, worth remembering.
func is_recording() -> bool:
	return SaveManager.save_path == SaveManager.SAVE_PATH


func _record_grid() -> void:
	if not is_recording() or not is_instance_valid(Globals.tile_grid):
		return
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		if is_instance_valid(tile) and tile.tile_resource:
			record_tile(ContentRegistry.get_tile_id(tile.tile_resource.resource_path))


func _on_ship_encountered(ship: Enemy) -> void:
	if is_recording():
		record_encounter(_enemy_id(ship))


func _on_enemy_destroyed(ship: Enemy) -> void:
	if is_recording():
		record_destroyed(_enemy_id(ship))


func _enemy_id(ship: Enemy) -> String:
	if not is_instance_valid(ship) or not ship.enemy_resource:
		return ""
	return ContentRegistry.get_enemy_id(ship.enemy_resource.resource_path)


func _count(id: String, key: String) -> void:
	if id.is_empty():
		return
	if not _enemies.has(id):
		_enemies[id] = {"encountered": 0, "destroyed": 0}
	_enemies[id][key] = int(_enemies[id].get(key, 0)) + 1
	_queue_write()


## A fight can destroy a handful of ships in one frame; they go to disk once.
func _queue_write() -> void:
	changed.emit()
	if _write_queued:
		return
	_write_queued = true
	_write.call_deferred()


func _write() -> void:
	_write_queued = false
	var payload: Dictionary = {
		"version": COLLECTION_VERSION,
		"tiles": _tiles.keys(),
		"enemies": _enemies,
		"regions": _regions.keys(),
		"families": _families,
	}
	var file: FileAccess = FileAccess.open(collection_path, FileAccess.WRITE)
	if not file:
		push_error("CollectionManager: failed to open %s for writing" % collection_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))


## Reads the collection back from disk, replacing what's in memory. A missing
## or unreadable file is an empty collection.
func load_collection() -> void:
	_tiles.clear()
	_enemies.clear()
	_regions.clear()
	_families.clear()
	if not FileAccess.file_exists(collection_path):
		return
	var file: FileAccess = FileAccess.open(collection_path, FileAccess.READ)
	if not file:
		push_error("CollectionManager: failed to open %s for reading" % collection_path)
		return
	# Parsed through an instance, which reports a bad file instead of logging
	# an engine error.
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("CollectionManager: collection file is corrupt, starting empty")
		return
	var data: Dictionary = json.data
	for id: Variant in data.get("tiles", []):
		_tiles[str(id)] = true
	for id: Variant in data.get("regions", []):
		_regions[str(id)] = true
	var families: Variant = data.get("families", {})
	if families is Dictionary:
		for id: Variant in families:
			_families[str(id)] = str(families[id])
	var enemies: Variant = data.get("enemies", {})
	if enemies is Dictionary:
		for id: Variant in enemies:
			var counts: Variant = enemies[id]
			if not counts is Dictionary:
				continue
			# JSON hands every number back as a float.
			_enemies[str(id)] = {
				"encountered": int(counts.get("encountered", 0)),
				"destroyed": int(counts.get("destroyed", 0)),
			}
