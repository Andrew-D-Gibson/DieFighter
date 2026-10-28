extends Node

## What the player has found across every run, for the codex on the main menu:
## each tile they've had on their grid, and each enemy they've met with how
## often they've met and destroyed it. Kept in its own file, since the run's
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


func record_encounter(id: String) -> void:
	_count(id, "encountered")


func record_destroyed(id: String) -> void:
	_count(id, "destroyed")


## Forgets everything found, on disk too.
func clear() -> void:
	_tiles.clear()
	_enemies.clear()
	_write()


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
