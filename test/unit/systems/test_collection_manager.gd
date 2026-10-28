extends "res://test/helpers/die_fighter_test.gd"
## CollectionManager: what the codex has found survives a reload, the game's
## own events fill it in, and only the player's own runs count.
##
## Event tests use the autoload, which die_fighter_test already points at a
## scratch file; the reload tests use their own instance.

const CollectionManagerScript: GDScript = preload("res://Source/Systems/Autoloads/collection_manager.gd")
const RELOAD_PATH: String = "user://test_collection_reload.json"
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const ENEMY_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyManager/enemy_manager.tscn")
const ATTACKER: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/attacker.tres")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const AMPLIFIER: TileResource = preload("res://Source/Content/Tiles/TileResources/amplifier.tres")


func before_each() -> void:
	super()
	CollectionManager.clear()


func after_each() -> void:
	CollectionManager.clear()
	DirAccess.remove_absolute(RELOAD_PATH)
	super()


func _fresh_collection() -> Node:
	var collection: Node = autofree(CollectionManagerScript.new())
	collection.collection_path = RELOAD_PATH
	return collection


func _ship(resource: EnemyResource = ATTACKER) -> Enemy:
	var ship: Enemy = autofree(ENEMY_SCENE.instantiate())
	ship.enemy_resource = resource
	return ship


func test_what_was_found_survives_a_reload() -> void:
	var collection: Node = _fresh_collection()
	collection.clear()
	collection.record_tile("amplifier")
	collection.record_encounter("attacker")
	collection.record_encounter("attacker")
	collection.record_destroyed("attacker")
	collection._write()

	var reloaded: Node = _fresh_collection()
	assert_true(reloaded.has_tile("amplifier"))
	assert_false(reloaded.has_tile("shield"))
	assert_true(reloaded.has_enemy("attacker"))
	assert_eq(reloaded.times_encountered("attacker"), 2)
	assert_eq(reloaded.times_destroyed("attacker"), 1)
	assert_eq(reloaded.times_encountered("raider"), 0)


func test_a_corrupt_file_reads_as_empty() -> void:
	var file: FileAccess = FileAccess.open(RELOAD_PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()

	var collection: Node = _fresh_collection()
	assert_false(collection.has_tile("amplifier"))
	assert_false(collection.has_enemy("attacker"))


func test_a_ship_met_and_destroyed_is_counted() -> void:
	var ship: Enemy = _ship()
	Events.ship_encountered.emit(ship)
	Events.enemy_destroyed.emit(ship)
	Events.ship_encountered.emit(_ship())

	assert_eq(CollectionManager.times_encountered("attacker"), 2)
	assert_eq(CollectionManager.times_destroyed("attacker"), 1)


func test_lab_and_autopilot_runs_dont_count() -> void:
	# Both point the run's save somewhere other than the player's own.
	SaveManager.save_path = "user://test_somewhere_else.json"
	Events.ship_encountered.emit(_ship())
	SaveManager.save_path = SaveManager.SAVE_PATH

	assert_false(CollectionManager.has_enemy("attacker"))


func test_the_tiles_on_the_grid_are_found_at_a_checkpoint() -> void:
	var grid: TileGrid = autofree(TileGrid.new())
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.tile_resource = AMPLIFIER
	grid.tile_locations[Vector2i(1, 1)] = tile
	Globals.tile_grid = grid

	assert_false(CollectionManager.has_tile("amplifier"))
	Events.game_saved.emit()
	assert_true(CollectionManager.has_tile("amplifier"))


func test_a_scenarios_ships_are_met_on_arrival_and_a_launched_one_too() -> void:
	Globals.state_manager = null
	var manager: EnemyManager = add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	var scenario: ScenarioResource = ScenarioResource.new()
	var roster: Array[EnemyStateRewardResource] = []
	for resource: EnemyResource in [ATTACKER, INTERCEPTOR]:
		var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
		spawn.enemy_resource = resource
		spawn.starting_state = ScenarioShipState.new()
		roster.append(spawn)
	scenario.starting_enemies = roster

	Events.load_scenario.emit(scenario)
	assert_eq(CollectionManager.times_encountered("attacker"), 1)
	assert_eq(CollectionManager.times_encountered("interceptor"), 1)

	await manager.launch_ship(INTERCEPTOR, manager.enemies[0])
	assert_eq(CollectionManager.times_encountered("interceptor"), 2)
