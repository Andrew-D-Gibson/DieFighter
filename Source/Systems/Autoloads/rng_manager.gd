extends Node

## Owns every RandomNumberGenerator "bucket" used by the game, keeping
## gameplay-affecting randomness reproducible from a seed while cosmetic/
## background randomness stays free-running.
enum Bucket { RUN, DICE, ENEMY_AI, TARGETING, REWARDS, BACKGROUND, COSMETIC }

var _rngs: Dictionary = {}


func _ready() -> void:
	for bucket: int in Bucket.values():
		_rngs[bucket] = RandomNumberGenerator.new()
	_rngs[Bucket.BACKGROUND].randomize()
	_rngs[Bucket.COSMETIC].randomize()
	Events.load_scenario.connect(_on_load_scenario)


func _on_load_scenario(scenario: ScenarioResource) -> void:
	seed_scenario(scenario.scenario_seed)


## Seeds the RUN bucket, which governs sector/shop generation for an entire
## playthrough. Pass an explicit seed to make a whole run replayable.
func start_new_run(run_seed: int = -1) -> void:
	if run_seed == -1:
		var seeder := RandomNumberGenerator.new()
		seeder.randomize()
		run_seed = seeder.randi()
	_rngs[Bucket.RUN].seed = run_seed


## Reseeds the deterministic per-scenario buckets from one scenario seed,
## deriving a distinct seed per bucket so they don't produce correlated
## sequences despite sharing the same source value.
func seed_scenario(scenario_seed: int) -> void:
	for bucket: int in [Bucket.DICE, Bucket.ENEMY_AI, Bucket.TARGETING, Bucket.REWARDS]:
		_rngs[bucket].seed = hash(str(scenario_seed) + str(bucket))


func get_rng(bucket: Bucket) -> RandomNumberGenerator:
	return _rngs[bucket]


func randi(bucket: Bucket) -> int:
	return _rngs[bucket].randi()


func randi_range(bucket: Bucket, from: int, to: int) -> int:
	return _rngs[bucket].randi_range(from, to)


func randf(bucket: Bucket) -> float:
	return _rngs[bucket].randf()


func randf_range(bucket: Bucket, from: float, to: float) -> float:
	return _rngs[bucket].randf_range(from, to)


func pick_random(bucket: Bucket, array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[_rngs[bucket].randi_range(0, array.size() - 1)]


## Array.shuffle() always draws from the global RNG, so a manual
## Fisher-Yates shuffle is required to shuffle deterministically.
func shuffle_array(bucket: Bucket, array: Array) -> void:
	var rng: RandomNumberGenerator = _rngs[bucket]
	for i in range(array.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
