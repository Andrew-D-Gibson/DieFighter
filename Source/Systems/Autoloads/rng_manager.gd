extends Node

## Owns every RandomNumberGenerator "bucket" used by the game, keeping
## gameplay-affecting randomness reproducible from a seed while cosmetic/
## background randomness stays free-running.
enum Bucket { RUN, DICE, ENEMY_AI, TARGETING, REWARDS, BACKGROUND, COSMETIC }

var _rngs: Dictionary = {}

## The buckets reseeded from each scenario's seed. BACKGROUND is among them
## because a background can carry a gameplay rule (BackgroundModifierResource):
## picking it from a free-running stream meant reloading a scenario could land
## the player under a different rule.
const _SCENARIO_BUCKETS: Array[Bucket] = [
	Bucket.DICE, Bucket.ENEMY_AI, Bucket.TARGETING, Bucket.REWARDS, Bucket.BACKGROUND
]

## The per-scenario buckets a mid-scenario checkpoint saves. BACKGROUND is left
## out: it's only drawn at arrival, and cosmetic effects draw on it afterwards.
const _CHECKPOINT_BUCKETS: Array[Bucket] = [
	Bucket.DICE, Bucket.ENEMY_AI, Bucket.TARGETING, Bucket.REWARDS
]


func _ready() -> void:
	for bucket: int in Bucket.values():
		_rngs[bucket] = RandomNumberGenerator.new()
	_rngs[Bucket.BACKGROUND].randomize()
	_rngs[Bucket.COSMETIC].randomize()
	Events.load_scenario.connect(_on_load_scenario)
	Events.load_game_save.connect(_on_load_game_save)


## The seed is stored on the ScenarioResource, but a sector can hold the same
## resource in several slots (every shop, fate and empty scenario is one shared
## object), and they all carry whichever seed was written last. Mixing in the
## map slot keeps two shops in one sector from rolling identical stock.
## Globals.map already points at the destination when load_scenario fires.
func _on_load_scenario(scenario: ScenarioResource) -> void:
	var slot: int = 0
	if is_instance_valid(Globals.map):
		slot = Globals.map.current_scenario_index
	seed_scenario(hash([scenario.scenario_seed, slot]))

	# Continuing a save taken partway through this scenario: pick the streams up
	# where they were, so the rest of the scenario rolls what it would have.
	# Nothing that runs while the scenario is rebuilt draws from these buckets
	# (enemies, offers and the shop come back from the save, not re-rolled).
	if is_instance_valid(Globals.state_manager):
		restore_states(Globals.state_manager.get_restore().get("rng", {}))


## Picks the run-wide stream up where the save left it, so the sectors still to
## be generated and Fate's advance come out as they would have. Connected
## before Map's own load_game_save listener, which is what draws from it next.
func _on_load_game_save(game_save: GameSaveResource) -> void:
	restore_states(game_save.rng_states)


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
	for bucket: int in _SCENARIO_BUCKETS:
		_rngs[bucket].seed = hash(str(scenario_seed) + str(bucket))


## RandomNumberGenerator.state for the given buckets, keyed by bucket name and
## stored as strings (JSON would round an int64).
func capture_states(buckets: Array[Bucket]) -> Dictionary:
	var out: Dictionary = {}
	for bucket: Bucket in buckets:
		out[Bucket.find_key(bucket)] = str(_rngs[bucket].state)
	return out


func capture_run_state() -> Dictionary:
	return capture_states([Bucket.RUN])


func capture_scenario_states() -> Dictionary:
	return capture_states(_CHECKPOINT_BUCKETS)


## Inverse of capture_states(). Unknown names are ignored.
func restore_states(states: Dictionary) -> void:
	for bucket_name: Variant in states:
		if not Bucket.has(bucket_name):
			continue
		_rngs[Bucket[bucket_name]].state = int(str(states[bucket_name]))


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
