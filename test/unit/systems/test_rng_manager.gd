extends "res://test/helpers/die_fighter_test.gd"
## RNGManager determinism: the promise that a Continue replays the same rolls.
## Uses a fresh instance, not the autoload, so tests can't disturb each other.

const RNGManagerScript: GDScript = preload("res://Source/Systems/Autoloads/rng_manager.gd")
const Bucket := preload("res://Source/Systems/Autoloads/rng_manager.gd").Bucket

var rng: Node


func before_each() -> void:
	super()
	rng = RNGManagerScript.new()
	add_child_autofree(rng)


func _draws(bucket: int, count: int = 5) -> Array[int]:
	var out: Array[int] = []
	for i: int in count:
		out.append(rng.randi(bucket))
	return out


func test_the_same_scenario_seed_replays_the_same_rolls() -> void:
	rng.seed_scenario(1234)
	var first := _draws(Bucket.DICE)
	rng.seed_scenario(1234)
	assert_eq(_draws(Bucket.DICE), first)


func test_scenario_buckets_are_not_correlated() -> void:
	rng.seed_scenario(1234)
	assert_ne(_draws(Bucket.DICE), _draws(Bucket.ENEMY_AI))


func test_seeding_a_scenario_leaves_the_run_stream_alone() -> void:
	rng.start_new_run(99)
	var before: Dictionary = rng.capture_run_state()
	rng.seed_scenario(1234)
	assert_eq(rng.capture_run_state(), before)


func test_seeding_a_scenario_leaves_cosmetics_free_running() -> void:
	var before: int = rng.get_rng(Bucket.COSMETIC).state
	rng.seed_scenario(1234)
	assert_eq(rng.get_rng(Bucket.COSMETIC).state, before)


func test_a_run_seed_replays_the_run() -> void:
	rng.start_new_run(42)
	var first := _draws(Bucket.RUN)
	rng.start_new_run(42)
	assert_eq(_draws(Bucket.RUN), first)


func test_captured_states_restore_mid_stream() -> void:
	rng.seed_scenario(7)
	_draws(Bucket.DICE, 3)
	var saved: Dictionary = rng.capture_scenario_states()
	var expected := _draws(Bucket.DICE)

	rng.seed_scenario(8)  # wander off
	rng.restore_states(saved)
	assert_eq(_draws(Bucket.DICE), expected)


func test_states_are_stored_as_strings_to_survive_json() -> void:
	# JSON has one number type, a double, which can't hold every int64.
	rng.seed_scenario(7)
	var saved: Dictionary = rng.capture_scenario_states()
	for bucket_name: String in saved:
		assert_typeof(saved[bucket_name], TYPE_STRING)

	var through_json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var expected := _draws(Bucket.DICE)
	rng.restore_states(through_json)
	assert_eq(_draws(Bucket.DICE), expected)


func test_checkpoints_leave_the_background_bucket_out() -> void:
	assert_false(rng.capture_scenario_states().has("BACKGROUND"))


func test_restore_ignores_unknown_bucket_names() -> void:
	rng.seed_scenario(7)
	var expected := _draws(Bucket.DICE)
	rng.seed_scenario(7)
	rng.restore_states({"NOT_A_BUCKET": "123"})
	assert_eq(_draws(Bucket.DICE), expected)


func test_shuffle_is_deterministic_and_a_permutation() -> void:
	var source: Array = range(20)
	rng.seed_scenario(5)
	var a: Array = source.duplicate()
	rng.shuffle_array(Bucket.REWARDS, a)
	rng.seed_scenario(5)
	var b: Array = source.duplicate()
	rng.shuffle_array(Bucket.REWARDS, b)

	assert_eq(a, b)
	var sorted: Array = a.duplicate()
	sorted.sort()
	assert_eq(sorted, source)


func test_pick_random_from_nothing_is_null() -> void:
	assert_null(rng.pick_random(Bucket.REWARDS, []))


func test_ranges_are_inclusive_and_bounded() -> void:
	rng.seed_scenario(3)
	var seen: Dictionary = {}
	for i: int in 500:
		seen[rng.randi_range(Bucket.DICE, 1, 6)] = true
	var faces: Array = seen.keys()
	faces.sort()
	assert_eq(faces, [1, 2, 3, 4, 5, 6], "every face, and nothing else")
