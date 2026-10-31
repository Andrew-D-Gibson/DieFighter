extends "res://test/helpers/die_fighter_test.gd"
## TileUnlocks: which tiles a player's own run can offer, and how each new
## sector unlocks the next family exactly once.

const _SENSOR_SPIKE: String = "res://Source/Content/Tiles/TileResources/sensor_spike.tres"
const _SIGNAL_RELAY: String = "res://Source/Content/Tiles/TileResources/signal_relay.tres"
const _DAMAGE: String = "res://Source/Content/Tiles/TileResources/damage.tres"


func before_each() -> void:
	super()
	CollectionManager.clear_families()


func after_each() -> void:
	CollectionManager.clear_families()
	SaveManager.save_path = SaveManager.SAVE_PATH
	super()


func _family(id: String) -> TileFamilyResource:
	var family: TileFamilyResource = TileUnlocks.family_by_id(id)
	assert_not_null(family, "no family '%s' in the unlock order" % id)
	return family


func test_a_new_player_is_only_offered_basic_tiles() -> void:
	var pool: Array[TileResource] = [load(_DAMAGE), load(_SIGNAL_RELAY)]
	var offered: Array[TileResource] = TileUnlocks.filter_pool(pool)
	assert_eq(offered.size(), 1)
	assert_eq(offered[0].resource_path, _DAMAGE)


func test_unlocking_a_family_adds_its_tiles() -> void:
	CollectionManager.record_family("relays")
	assert_true(TileUnlocks.is_tile_available(load(_SIGNAL_RELAY)))


func test_a_tile_in_two_families_waits_for_both() -> void:
	var spike: TileResource = load(_SENSOR_SPIKE)
	assert_eq(TileUnlocks.families_of(spike).size(), 2)
	CollectionManager.record_family("relays")
	assert_false(TileUnlocks.is_tile_available(spike))
	assert_false(_family("relays").tiles.size() == TileUnlocks.tiles_opened_by(_family("relays")).size(),
		"the relays card shouldn't show tiles still waiting on another family")
	CollectionManager.record_family("debuffs")
	assert_true(TileUnlocks.is_tile_available(spike))
	assert_has(TileUnlocks.tiles_opened_by(_family("debuffs")), spike)


func test_each_claim_unlocks_the_next_family_in_order() -> void:
	var first: TileFamilyResource = TileUnlocks.unlock_for(TileUnlocks.claim_for(7, 1))
	var second: TileFamilyResource = TileUnlocks.unlock_for(TileUnlocks.claim_for(7, 2))
	assert_eq(first, TileUnlocks.families()[0])
	assert_eq(second, TileUnlocks.families()[1])
	assert_eq(TileUnlocks.unlocked_count(), 2)


func test_replaying_a_jump_shows_the_same_family_again() -> void:
	var claim: String = TileUnlocks.claim_for(7, 1)
	var first: TileFamilyResource = TileUnlocks.unlock_for(claim)
	assert_eq(TileUnlocks.unlock_for(claim), first)
	assert_eq(TileUnlocks.unlocked_count(), 1)


func test_an_unknown_run_always_unlocks_fresh() -> void:
	assert_eq(TileUnlocks.claim_for(-1, 1), "")
	TileUnlocks.unlock_for(TileUnlocks.claim_for(-1, 1))
	TileUnlocks.unlock_for(TileUnlocks.claim_for(-1, 1))
	assert_eq(TileUnlocks.unlocked_count(), 2)


func test_nothing_left_to_unlock_returns_null() -> void:
	for family: TileFamilyResource in TileUnlocks.families():
		CollectionManager.record_family(family.id())
	assert_null(TileUnlocks.unlock_for(TileUnlocks.claim_for(7, 1)))


func test_lab_and_autopilot_runs_see_every_tile_and_unlock_nothing() -> void:
	SaveManager.save_path = "user://test_somewhere_else.json"
	var pool: Array[TileResource] = [load(_DAMAGE), load(_SIGNAL_RELAY)]
	assert_eq(TileUnlocks.filter_pool(pool).size(), 2)
	assert_null(TileUnlocks.unlock_for(TileUnlocks.claim_for(7, 1)))
	assert_eq(TileUnlocks.unlocked_count(), 0)


func test_unlocks_survive_a_reload() -> void:
	CollectionManager.record_family("burn", "7:1")
	await wait_physics_frames(1)
	CollectionManager.load_collection()
	assert_true(CollectionManager.has_family("burn"))
	assert_eq(CollectionManager.family_for_claim("7:1"), "burn")


func test_the_run_seed_rides_along_with_the_run_state() -> void:
	var rng: Node = load("res://Source/Systems/Autoloads/rng_manager.gd").new()
	add_child_autofree(rng)
	rng.start_new_run(1234)
	var states: Dictionary = rng.capture_run_state()
	rng.current_run_seed = -1
	rng.restore_states(states)
	assert_eq(rng.current_run_seed, 1234)
