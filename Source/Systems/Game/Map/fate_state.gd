class_name FateState
extends RefCounted
## Fate's hold on a sector: how far it has advanced along the road, which
## tiles it takes on the next jump, and what it turns them into. Pure rules
## over the sector's scenario list (road); Map draws all of it.
##
## Seeded maps depend on this. Fate draws from the RUN stream in two places
## only (pick_danger_range() and pick_stray_danger(), on arrival in a sector
## and on every jump), and corrupt() hashes rather than draws. Changing what
## is drawn, or in what order, moves every seeded map and AutoPilot
## transcript after it.

## The tiles of the sector, left to right. Map's scenario_list: the same
## array, not a copy, so a slot changed on either is changed on both.
var road: Array[ScenarioResource] = []

## The last tile Fate has corrupted, counting from the sector's left edge.
## -1 before it has taken any.
var fate_index: int = -1
## How many tiles past fate_index Fate takes on the next jump.
var scenarios_in_danger: int = 0
## Tiles past the danger zone that Fate has reached out and marked at random.
## Like the danger zone, they're corrupted on the next jump.
var stray_danger_indices: Array[int] = []

# Set by Map from its exports; see there.
var empty_scenario: ScenarioResource
var fate_scenario: ScenarioResource
var fate_variants: Array[ScenarioResource] = []
var open_gate_scenario: ScenarioResource
var stray_danger_chance: float = DEFAULT_STRAY_DANGER_CHANCE

const DEFAULT_STRAY_DANGER_CHANCE: float = 0.1


# ── A new sector, and saves ─────────────────────────────────────────────────

## Fate starts just off the sector's left edge: nothing is corrupted yet, only
## the first one or two tiles are under threat.
func reset() -> void:
	fate_index = -1
	stray_danger_indices.clear()
	pick_danger_range()


## Fate's progress through the sector, for the save.
func to_dict() -> Dictionary:
	return {
		"fate_index": fate_index,
		"scenarios_in_danger": scenarios_in_danger,
		"stray_danger_indices": stray_danger_indices.duplicate(),
	}


## Puts back what to_dict() recorded, rather than re-rolling: reset() would
## hand back the ground Fate had already taken and shift every roll after it.
func restore(state: Dictionary) -> void:
	# The left_ keys are from saves written while Fate could close in from
	# both ends.
	fate_index = state.get("fate_index", state.get("left_fate_index", 0))
	scenarios_in_danger = state.get("scenarios_in_danger", state.get("left_scenarios_in_danger", 0))
	stray_danger_indices.assign(state.get("stray_danger_indices", []))


# ── Questions ───────────────────────────────────────────────────────────────

## Whether Fate takes the tile at [param index] on the next jump. The sector's
## gate never: the player must always be able to leave.
func is_in_danger(index: int) -> bool:
	if road[index].sector_gate_scenario:
		return false
	return index in stray_danger_indices or (
		index > fate_index and index <= fate_index + scenarios_in_danger
	)


## Every tile in danger, grouped into runs of neighbours as [first, last]
## indices, left to right.
func danger_runs() -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	for idx: int in range(fate_index + 1, road.size()):
		if not is_in_danger(idx):
			continue
		if not runs.is_empty() and runs.back().y == idx - 1:
			runs[-1] = Vector2i(runs.back().x, idx)
		else:
			runs.append(Vector2i(idx, idx))
	return runs


## Whether [param scenario] is one of Fate's: a tile it has already taken.
func is_fate_scenario(scenario: ScenarioResource) -> bool:
	return scenario != null and (scenario == fate_scenario or scenario in fate_variants)


## Whether the tile at [param index] is a stray Fate tile ahead of the black
## hole's advancing zone.
func is_stray_fate_slot(index: int) -> bool:
	if index < 0 or index >= road.size():
		return false
	return index > fate_index and is_fate_scenario(road[index])


# ── Changes ─────────────────────────────────────────────────────────────────

## The player is leaving the tile at [param leaving] for [param arriving]: the
## tile they leave is emptied (or Fate's, if it's already behind the line),
## Fate takes every tile in danger, advances, and marks what it takes next.
## Returns the tiles it took.
func advance(leaving: int, arriving: int) -> Array[int]:
	var taken: Array[int] = []
	for idx: int in range(fate_index + 1, road.size()):
		if is_in_danger(idx):
			taken.append(idx)

	clear_slot(leaving)
	for idx: int in range(fate_index + 1, fate_index + 1 + scenarios_in_danger):
		if not road[idx].sector_gate_scenario:
			corrupt(idx)
	for idx: int in stray_danger_indices:
		if not road[idx].sector_gate_scenario:
			corrupt(idx)
	fate_index += scenarios_in_danger

	pick_danger_range()
	pick_stray_danger(arriving)
	return taken


## Marks the tile at [param index] as cleared: empty, or Fate's if Fate is
## already past it. Never a sector-gate tile (boss fights, the jump gate),
## which must never be overwritten.
func clear_slot(index: int) -> void:
	if road[index].sector_gate_scenario:
		return
	if index <= fate_index:
		corrupt(index)
	else:
		road[index] = empty_scenario


## The player beat the boss guarding the gate at [param index]. The gate stays
## a gate, but nobody guards it now.
func open_gate(index: int) -> void:
	if road[index].sector_gate_scenario and open_gate_scenario:
		road[index] = open_gate_scenario


## Hands the tile at [param idx] to Fate, as one of its encounters. The pick is
## a hash of the RUN stream's state and the tile rather than a draw from it,
## so adding variants leaves every seeded map otherwise unchanged, the same way
## repair stations are placed.
func corrupt(idx: int) -> void:
	if fate_variants.is_empty():
		road[idx] = fate_scenario
		return
	var pool: Array[ScenarioResource] = [fate_scenario]
	pool.append_array(fate_variants)
	var roll: int = hash([RNGManager.get_rng(RNGManager.Bucket.RUN).state, idx, "fate"])
	road[idx] = pool[posmod(roll, pool.size())]


## How many tiles Fate threatens next: usually 2. Fate stops one short of the
## last tile, the jump gate, so the gate is never corrupted, never covered by
## the corrupted zone, and never in danger.
func pick_danger_range() -> void:
	var max_in_danger: int = mini(2, road.size() - fate_index - 2)
	if max_in_danger <= 0:
		scenarios_in_danger = 0
	else:
		scenarios_in_danger = RNGManager.randi_range(RNGManager.Bucket.RUN, 1, max_in_danger)


## Rolls stray_danger_chance for every tile past the danger zone. The tile the
## player is arriving at is spared — corrupting it underneath them would read
## as a bug, not a threat — as are the gate and tiles Fate already holds.
## Fate never holds more than half of the road ahead (see
## stray_corruption_cap()), so a sector can't rot into a wall of its
## encounters before the danger zone even gets there.
func pick_stray_danger(arriving_index: int) -> void:
	stray_danger_indices.clear()
	var first_ahead: int = fate_index + scenarios_in_danger + 1
	var cap: int = stray_corruption_cap(first_ahead)
	var corrupted: int = 0
	for idx: int in range(first_ahead, road.size()):
		if is_fate_scenario(road[idx]):
			corrupted += 1
	for idx: int in range(first_ahead, road.size()):
		if idx == arriving_index \
		or road[idx].sector_gate_scenario \
		or is_fate_scenario(road[idx]):
			continue
		# Roll every tile even once the cap is reached: the RUN stream then
		# advances exactly as it did before the cap existed, so seeded maps
		# (the tutorial's, AutoPilot transcripts) only differ where it bites.
		var marked: bool = RNGManager.randf(RNGManager.Bucket.RUN) < stray_danger_chance
		if marked and corrupted < cap:
			stray_danger_indices.append(idx)
			corrupted += 1


## How many tiles past the danger zone Fate may hold, counting its strays:
## half of them, rounded down. The gate doesn't count, since Fate can never
## take it. [param first_ahead] is the first tile past the danger zone.
func stray_corruption_cap(first_ahead: int) -> int:
	var ahead: int = 0
	for idx: int in range(first_ahead, road.size()):
		if not road[idx].sector_gate_scenario:
			ahead += 1
	@warning_ignore("integer_division")
	return ahead / 2
