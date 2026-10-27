extends "res://test/helpers/die_fighter_test.gd"
## A tile answering ON_PLAYER_FATAL_DAMAGE (Emergency Shield) is a death save.
## Health re-checks the hull straight after fatal_damage returns, so the save
## has to land inside that signal; the tile's chain only plays afterwards.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const EMERGENCY_SHIELD: TileResource = preload("res://Source/Content/Tiles/TileResources/emergency_shield.tres")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")

var engine: RecordingEngine
var health: Health


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager

	var player: Player = make_player()
	health = autofree(Health.new())
	health.max_health = 10
	health.health = 3
	player.health = health
	Globals.player = player


## A tile outside the tree, listening for the fatal blow the way the Player
## relays it in the game. Its sprite is dropped first so assigning the
## resource doesn't start the gray-out tween, which needs the tree.
func _listening_tile(resource: TileResource) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	health.fatal_damage.connect(tile._on_player_fatal_damage)
	return tile


func test_emergency_shield_survives_a_killing_blow_at_one_hull() -> void:
	_listening_tile(EMERGENCY_SHIELD)
	health.take_damage(5)
	assert_false(health.is_dead)
	assert_eq(health.health, 1)
	assert_eq(engine.injected_of(TileEventTriggeredEvent).size(), 1, "the shield chain plays")


func test_the_save_is_spent_on_the_first_blow() -> void:
	# The chain burns the tile out, but a second blow can land before it does.
	_listening_tile(EMERGENCY_SHIELD)
	health.take_damage(5)
	health.take_damage(5)
	assert_true(health.is_dead)
	assert_eq(engine.injected_of(TileEventTriggeredEvent).size(), 1)


func test_two_shields_only_burn_one() -> void:
	_listening_tile(EMERGENCY_SHIELD)
	_listening_tile(EMERGENCY_SHIELD)
	health.take_damage(5)
	assert_eq(health.health, 1)
	assert_eq(engine.injected_of(TileEventTriggeredEvent).size(), 1)


func test_a_tile_on_offer_saves_nothing() -> void:
	_listening_tile(EMERGENCY_SHIELD).on_offer = true
	health.take_damage(5)
	assert_true(health.is_dead)


func test_a_tile_without_a_fatal_response_saves_nothing() -> void:
	_listening_tile(DAMAGE_TILE)
	health.take_damage(5)
	assert_true(health.is_dead)
	assert_eq(engine.injected.size(), 0)
