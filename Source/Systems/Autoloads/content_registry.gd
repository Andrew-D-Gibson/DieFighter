extends Node

## Maps short, stable string IDs to res:// resource paths for content that
## needs to be referenced from the save file (or the codex's collection), so saves don't break if a
## .tres gets renamed/moved and don't need to store raw res:// paths.

const _TILE_DIRS: Array[String] = [
	"res://Source/Content/Tiles/TileResources/",
]
const _SCENARIO_DIR: String = "res://Source/Content/ScenarioResources/Scenarios/"
const _ENEMY_DIR: String = "res://Source/Content/Enemies/EnemyResources/"

var _tile_id_to_path: Dictionary[String, String] = {}
var _tile_path_to_id: Dictionary[String, String] = {}
var _scenario_id_to_path: Dictionary[String, String] = {}
var _scenario_path_to_id: Dictionary[String, String] = {}
var _enemy_id_to_path: Dictionary[String, String] = {}
var _enemy_path_to_id: Dictionary[String, String] = {}


func _ready() -> void:
	for dir_location: String in _TILE_DIRS:
		for path: String in Utils.list_resource_paths(dir_location):
			_register_tile(path)
	for path: String in Utils.list_resource_paths(_SCENARIO_DIR, true):
		_register_scenario(path)
	for path: String in Utils.list_resource_paths(_ENEMY_DIR):
		_register_enemy(path)


func get_tile_path(id: String) -> String:
	if not _tile_id_to_path.has(id):
		push_error("ContentRegistry: no tile registered with id '%s'" % id)
		return ""
	return _tile_id_to_path[id]


func get_tile_id(path: String) -> String:
	if not _tile_path_to_id.has(path):
		push_error("ContentRegistry: no tile registered at path '%s'" % path)
		return ""
	return _tile_path_to_id[path]


## Every registered tile id, sorted.
func get_tile_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_tile_id_to_path.keys())
	ids.sort()
	return ids


func get_scenario_path(id: String) -> String:
	if not _scenario_id_to_path.has(id):
		push_error("ContentRegistry: no scenario registered with id '%s'" % id)
		return ""
	return _scenario_id_to_path[id]


## Every registered scenario id, unordered.
func get_scenario_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_scenario_id_to_path.keys())
	return ids


func get_scenario_id(path: String) -> String:
	if not _scenario_path_to_id.has(path):
		push_error("ContentRegistry: no scenario registered at path '%s'" % path)
		return ""
	return _scenario_path_to_id[path]


func get_enemy_path(id: String) -> String:
	if not _enemy_id_to_path.has(id):
		push_error("ContentRegistry: no enemy registered with id '%s'" % id)
		return ""
	return _enemy_id_to_path[id]


## Blank, quietly, for a resource that isn't one of the registered enemies
## (one built in code has no path at all).
func get_enemy_id(path: String) -> String:
	return _enemy_path_to_id.get(path, "")


## Every registered enemy id, sorted.
func get_enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_enemy_id_to_path.keys())
	ids.sort()
	return ids


func _register_tile(path: String) -> void:
	var res: Resource = ResourceLoader.load(path)
	if not res is TileResource:
		return
	_register(path, _tile_id_to_path, _tile_path_to_id, "tile")


func _register_scenario(path: String) -> void:
	var res: Resource = ResourceLoader.load(path)
	if not res is ScenarioResource:
		return
	_register(path, _scenario_id_to_path, _scenario_path_to_id, "scenario")


## Not loaded to check: everything in the folder is an enemy, and loading them
## all would pull every ship's graphics in at boot.
func _register_enemy(path: String) -> void:
	_register(path, _enemy_id_to_path, _enemy_path_to_id, "enemy")


func _register(
	path: String,
	id_to_path: Dictionary[String, String],
	path_to_id: Dictionary[String, String],
	kind: String
) -> void:
	var id: String = path.get_file().get_basename()
	if id_to_path.has(id):
		push_error("ContentRegistry: duplicate %s id '%s' (paths '%s' and '%s')" % [
			kind, id, id_to_path[id], path
		])
		return
	id_to_path[id] = path
	path_to_id[path] = id
