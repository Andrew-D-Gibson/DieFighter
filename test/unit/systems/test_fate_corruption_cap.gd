extends "res://test/helpers/die_fighter_test.gd"
## Fate's stray corruption: tiles past the danger zone it marks at random.
## It may hold at most half of them (rounded down, the gate not counted), so
## the road ahead never rots shut before the danger zone reaches it.

const _VIEWER_SCENE: PackedScene = preload("res://Source/Systems/Game/MainViewer/main_viewer.tscn")
## 11 encounters and the gate. With Fate off the left edge and 2 tiles in
## danger, tiles 2-10 are ahead of the danger zone: 9 of them, so the cap is 4.
const _SECTOR_SIZE: int = 12
const _IN_DANGER: int = 2
const _CAP: int = 4
## The player lands inside the danger zone, so every tile ahead is eligible.
const _ARRIVING: int = 1

var _map: Map


func before_each() -> void:
	super()
	var viewer: MainViewer = _VIEWER_SCENE.instantiate()
	add_child_autofree(viewer)
	_map = viewer.map
	Globals.jump_gate = null
	var sector: Array[ScenarioResource] = []
	for i: int in _SECTOR_SIZE - 1:
		sector.append(_map.empty_scenario)
	sector.append(_map.open_gate_scenario)
	_map.load_sector(sector, 0)
	_map.fate_index = -1
	_map.scenarios_in_danger = _IN_DANGER
	# Every roll marks its tile, so only the cap holds Fate back.
	_map.stray_danger_chance = 1.0


func test_the_cap_is_half_the_tiles_ahead_without_the_gate() -> void:
	assert_eq(_map._stray_corruption_cap(_IN_DANGER), _CAP)


func test_strays_stop_at_half_the_tiles_ahead() -> void:
	_map._pick_stray_danger(_ARRIVING)
	assert_eq(_map.stray_danger_indices.size(), _CAP)
	assert_eq(_map.stray_danger_indices, [2, 3, 4, 5] as Array[int], "the nearest tiles go first")


func test_tiles_fate_already_holds_count_toward_the_cap() -> void:
	for idx: int in [8, 9, 10]:
		_map.scenario_list[idx] = _map.fate_scenario
	_map._pick_stray_danger(_ARRIVING)
	assert_eq(_map.stray_danger_indices, [2] as Array[int], "3 held + 1 new = the cap")


func test_no_new_strays_once_fate_is_at_the_cap() -> void:
	for idx: int in [7, 8, 9, 10]:
		_map.scenario_list[idx] = _map.fate_scenario
	_map._pick_stray_danger(_ARRIVING)
	assert_true(_map.stray_danger_indices.is_empty())


func test_no_new_strays_when_fate_is_already_over_the_cap() -> void:
	for idx: int in [4, 5, 6, 7, 8, 9, 10]:
		_map.scenario_list[idx] = _map.fate_scenario
	_map._pick_stray_danger(_ARRIVING)
	assert_true(_map.stray_danger_indices.is_empty())


func test_capped_tiles_still_roll_so_seeded_maps_keep_their_stream() -> void:
	var rng: RandomNumberGenerator = RNGManager.get_rng(RNGManager.Bucket.RUN)
	var start: int = rng.state
	_map._pick_stray_danger(_ARRIVING)
	var after_pick: int = rng.state

	# One roll per eligible tile: 2-10, whether or not the cap let it through.
	rng.state = start
	for i: int in range(_IN_DANGER, _SECTOR_SIZE - 1):
		rng.randf()
	assert_eq(after_pick, rng.state)
