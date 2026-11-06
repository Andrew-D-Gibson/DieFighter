class_name SectorGenerator
extends Node
## Deals a sector's map: which encounter sits in each slot, where the player
## arrives, and every slot's seed. GameStateManager decides when a sector is
## dealt; this decides what is in it.
##
## Every draw comes off the RUN stream in a fixed order, so a seed always lays
## out the same map. The tutorial's seed 21 and every AutoPilot transcript
## depend on that: a change here that adds, drops or reorders a draw moves
## every seeded map. See ARCHITECTURE_OVERVIEW "Run Progression".

## How many encounters are dealt between the shops, elites and the mix,
## before the arrival and the gate are added. A sector is this plus two, plus
## [member added_stops], plus Fate's tile at its left edge (see generate()).
@export var sector_size: int = 18

## Stops dealt on top of [member sector_size], after the rest of the sector,
## from a generator of their own (see add_stops()). Separate from
## sector_size so a longer sector leaves every seeded map's opening as it
## was: the tutorial's seed 21 and every AutoPilot transcript.
@export var added_stops: int = 6
## How many of [member added_stops] are always events; the rest are events
## at the mix's usual chance. Events are where most choices that carve Fate's
## Die are made.
@export var added_events: int = 3

@export_category('Scenario Resources')
@export var empty_scenario: ScenarioResource
@export var shop_scenario: ScenarioResource
## The repair station: buy hull, sell tiles. See place_repair_stations().
@export var repair_scenario: ScenarioResource
## How many repair stations a sector holds, inclusive on both ends. A little
## rarer than shops (2-3): hull is the scarcer thing to buy, and with nothing
## else reliably healing, two stations a sector would make it cheap.
@export var repair_stations_per_sector: Vector2i = Vector2i(1, 2)
@export var combat_scenarios: Array[ScenarioResource]
@export var question_scenarios: Array[ScenarioResource]
## Optional fights a cut above the rest: tougher ships, rarer salvage. Shuffled
## in among a sector's other encounters, never two of the same in one sector.
@export var elite_scenarios: Array[ScenarioResource]
## How many elites a sector holds, inclusive on both ends.
@export var elites_per_sector: Vector2i = Vector2i(1, 2)
## Encounters the fleet sends after the player for what they did: the Compact
## collecting on a robbed shop. Unlike an encounter that merely may be dealt
## (ScenarioResource.standing_requirements in the lists above), these are
## met: as each sector is generated, those whose requirements the run's
## standing meets replace ordinary stops. See place_consequences().
@export var consequence_scenarios: Array[ScenarioResource]
## At most this many consequences in one sector, however many grudges the
## player has earned, so a cruel run isn't nothing but reckonings.
@export var consequences_per_sector: int = 1
## The boss guarding each sector's jump gate, in order. The gate is the
## sector's last tile and the only way out of it, so every boss here has to be
## beaten to progress. The last entry is reused if a run outlasts the list.
@export var gate_boss_scenarios: Array[ScenarioResource]

## Where the player arrives in the very first sector. Authored rather than
## random, so a new run always opens on the same deliberate first impression.
@export var starting_scenario: ScenarioResource

## The Inbound pilgrim who hands the player Fate's Die (LORE.md §5). Dealt into
## every first sector, a little way past the arrival, if the draw didn't deal
## it already. See place_fate_pilgrim().
@export var fate_pilgrim_scenario: ScenarioResource

## The furthest one jump goes: a die's top face.
const LONGEST_JUMP: int = 6

## Chance a slot in the mix is an event rather than a fight.
const _EVENT_CHANCE: float = 0.3

## Stops dealt into the next new run's first sector over whatever the draw put
## there, keyed by places from the arrival (positive is right). Set before the
## run is rolled, like RNGManager.next_run_seed, and used up by it. The
## tutorial pins the fight its jump lands in here.
static var next_run_pinned_stops: Dictionary[int, ScenarioResource] = {}


## Deals [param save]'s sector ([member GameSaveResource.sector_index]) into
## its sector_scenarios, and sets its current_scenario_index and
## arrival_index to the arrival. Replaces whatever was there, so it's safe to
## call again for the next sector.
func generate(save: GameSaveResource) -> void:
	# Read before anything is drawn: the stations are placed from it, after
	# the sector is otherwise finished. See place_repair_stations().
	var repair_placement_seed: int = hash([RNGManager.get_rng(RNGManager.Bucket.RUN).state, "repair"])
	var consequence_placement_seed: int = hash([RNGManager.get_rng(RNGManager.Bucket.RUN).state, "consequence"])
	var added_stops_seed: int = hash([RNGManager.get_rng(RNGManager.Bucket.RUN).state, "added"])
	var scenarios: Array[ScenarioResource] = []

	for i: int in range(RNGManager.randi_range(RNGManager.Bucket.RUN, 2, 3)):
		scenarios.append(shop_scenario)

	_add_elites(scenarios, save.sector_index)
	_add_mix(scenarios, save.sector_index)
	RNGManager.shuffle_array(RNGManager.Bucket.RUN, scenarios)

	# The jump gate, guarded by this sector's boss, is always the last tile.
	# Indexed rather than random: the boss is the one encounter the player is
	# guaranteed to meet once per sector, so it's the clearest place to show a
	# run getting harder.
	if not gate_boss_scenarios.is_empty():
		var boss_index: int = clampi(save.sector_index, 0, len(gate_boss_scenarios) - 1)
		scenarios.append(gate_boss_scenarios[boss_index])

	# The arrival goes somewhere in the first third.
	var arrival_index: int = RNGManager.randi_range(
		RNGManager.Bucket.RUN, 2, ceili(0.33 * scenarios.size())
	)
	scenarios.insert(arrival_index, _pick_arrival_scenario(scenarios, save.sector_index))

	# What the seed dealt, before anything scripted is pinned over it, for
	# add_stops() to tell fresh encounters from ones the sector holds: a pin
	# must change only its own slot.
	var as_dealt: Array[ScenarioResource] = scenarios.duplicate()
	_place_pinned_stops(scenarios, arrival_index)

	var replaceable: Array[ScenarioResource] = []
	replaceable.append_array(combat_scenarios)
	replaceable.append_array(question_scenarios)

	if save.sector_index == 0 and fate_pilgrim_scenario and fate_pilgrim_scenario not in scenarios:
		place_fate_pilgrim(scenarios, arrival_index, replaceable,
			fate_pilgrim_scenario, hash([repair_placement_seed, "pilgrim"]))
	# From here on only fights make way for what's placed. Events are where
	# most of Fate's Die is carved, so a sector keeps every one it was dealt,
	# and the pilgrim, an event, keeps its slot: it hands over the die, and a
	# repair station placed in the same band used to overwrite it.
	var fights: Array[ScenarioResource] = combat_scenarios.duplicate()

	for scenario: ScenarioResource in scenarios:
		scenario.scenario_seed = RNGManager.randi(RNGManager.Bucket.RUN)

	# After the RUN draws (the loop above spends one per stop), and before the
	# stations and consequences, which then have the whole longer sector to
	# be placed in.
	var events: Array[ScenarioResource] = ScenarioResource.allowed_in_sector(
		question_scenarios, save.sector_index)
	events.erase(fate_pilgrim_scenario)
	add_stops(
		scenarios,
		as_dealt,
		arrival_index,
		events,
		ScenarioResource.allowed_in_sector(combat_scenarios, save.sector_index),
		added_stops,
		added_events,
		_EVENT_CHANCE,
		added_stops_seed
	)

	if repair_scenario:
		place_repair_stations(
			scenarios,
			arrival_index,
			fights,
			repair_scenario,
			repair_stations_per_sector,
			repair_placement_seed
		)

	# After the stations, which they never displace (a station isn't a
	# fight). Read against the standing as it is now: the sector being
	# generated answers for everything the player did before its gate.
	place_consequences(
		scenarios,
		arrival_index,
		fights,
		ScenarioResource.allowed_in_sector(consequence_scenarios, save.sector_index),
		consequences_per_sector,
		consequence_placement_seed
	)

	# The encounters that can earn a locked ship (ShipUnlocks), one each,
	# from a generator of their own: a run with nothing left to earn deals
	# the map its seed always did. A reckoning placed above isn't in
	# replaceable, so it stays.
	var unlocks: Array[ScenarioResource] = ShipUnlocks.scenarios_for_sector(save.sector_index)
	place_consequences(
		scenarios,
		arrival_index,
		replaceable,
		unlocks,
		unlocks.size(),
		hash([repair_placement_seed, "ship_unlock"])
	)

	# Fate's tile at the sector's left edge, against the black hole: Fate
	# already holds it when the player arrives (FateState.reset() takes the
	# first tile). Dealt as an empty slot, last and without a draw, so every
	# other stop keeps its place relative to the arrival.
	scenarios.insert(0, empty_scenario)
	arrival_index += 1

	save.sector_scenarios = scenarios
	save.current_scenario_index = arrival_index
	save.arrival_index = arrival_index


## Fills the sector up to [member sector_size] with a blend of events and
## fights, none repeated while there are others left.
func _add_mix(scenarios: Array[ScenarioResource], sector_index: int) -> void:
	# Some ships wait for a later sector (ScenarioResource.earliest_sector).
	# Filtering the lists rather than the picks keeps every draw in place, so
	# a seeded map keeps its layout and only who is in a fight changes.
	var questions: Array[ScenarioResource] = ScenarioResource.allowed_in_sector(
		question_scenarios, sector_index
	)
	var combats: Array[ScenarioResource] = ScenarioResource.allowed_in_sector(
		combat_scenarios, sector_index
	)

	for i: int in range(sector_size - scenarios.size()):
		var question_options: Array[ScenarioResource] = Utils.array_while_excluding(questions, scenarios)
		var combat_options: Array[ScenarioResource] = Utils.array_while_excluding(combats, scenarios)

		# Rolled even when there are no events left, so running out doesn't
		# shift every later roll.
		var question_roll: float = RNGManager.randf(RNGManager.Bucket.RUN)
		if not question_options.is_empty() and question_roll <= _EVENT_CHANCE:
			scenarios.append(_pick_one(question_options))
		elif not combat_options.is_empty():
			scenarios.append(_pick_one(combat_options))
		else:
			# Both lists ran dry (a sector bigger than its content): repeat
			# something rather than leave a hole.
			var all_scenarios: Array[ScenarioResource] = []
			all_scenarios.append_array(combats)
			all_scenarios.append_array(questions)
			if all_scenarios.is_empty():
				scenarios.append(empty_scenario)
			else:
				scenarios.append(_pick_one(all_scenarios))


## Rolls this sector's elites into the encounter list, before it's shuffled.
## Each elite appears at most once per sector, so a short elite list caps the
## count rather than repeating a fight.
func _add_elites(scenarios: Array[ScenarioResource], sector_index: int) -> void:
	var count: int = RNGManager.randi_range(
		RNGManager.Bucket.RUN, elites_per_sector.x, elites_per_sector.y
	)
	var elites: Array[ScenarioResource] = ScenarioResource.allowed_in_sector(
		elite_scenarios, sector_index
	)
	for i: int in range(count):
		var options: Array[ScenarioResource] = Utils.array_while_excluding(elites, scenarios)
		if options.is_empty():
			return
		scenarios.append(_pick_one(options))


## Where the player drops out of hyperspace when a sector begins.
##
## Sector 1 always uses the authored starting_scenario so a new run opens the
## same way every time. Later sectors arrive somewhere else entirely — landing
## on the identical encounter three times in one run makes the jump gate feel
## like a reset rather than progress.
func _pick_arrival_scenario(scenarios: Array[ScenarioResource], sector_index: int) -> ScenarioResource:
	# Only this sector's own events: landing in the Spine on a Tail encounter
	# would make the jump gate feel like it led nowhere.
	var events: Array[ScenarioResource] = ScenarioResource.allowed_in_sector(
		question_scenarios, sector_index
	)
	if sector_index == 0 or events.is_empty():
		return starting_scenario

	var unused: Array[ScenarioResource] = Utils.array_while_excluding(events, scenarios)
	if unused.is_empty():
		unused = events

	return RNGManager.pick_random(RNGManager.Bucket.RUN, unused)


## Puts next_run_pinned_stops in their places, and spends them. Each replaces
## a stop rather than adding a draw, so the RUN stream, and with it the rest
## of a seeded map, comes out exactly as the seed has it. Never the arrival or
## the gate.
static func _place_pinned_stops(scenarios: Array[ScenarioResource], arrival_index: int) -> void:
	var pinned: Dictionary[int, ScenarioResource] = next_run_pinned_stops
	next_run_pinned_stops = {}
	for offset: int in pinned:
		var slot: int = arrival_index + offset
		if offset == 0 or slot < 0 or slot >= scenarios.size() - 1:
			push_warning("SectorGenerator: no stop %+d from the arrival to pin %s to." % [
				offset, pinned[offset].resource_path.get_file()])
			continue
		scenarios[slot] = pinned[offset]


## Swaps [param count_range] ordinary stops in a finished sector for repair
## stations: anything in [param replaceable] (generate() passes the fights)
## further from the arrival than one jump can reach, before the gate.
##
## Done last, from its own generator seeded off the RUN stream's state rather
## than by drawing from it. Drawing would shift every roll after it, so every
## seeded map (the tutorial's seed 21, every AutoPilot transcript) would come
## out different. This way the RUN stream is untouched, and a sector only
## differs where a station replaced a stop.
##
## Why beyond a jump's reach: the arrival's neighbourhood stays exactly as the
## RUN stream dealt it, which the tutorial's script relies on, and a station is
## a stop to plan a route toward, a pit stop before the gate.
static func place_repair_stations(
	scenarios: Array[ScenarioResource],
	arrival_index: int,
	replaceable: Array[ScenarioResource],
	station: ScenarioResource,
	count_range: Vector2i,
	placement_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed

	var candidates: Array[int] = []
	# The last slot is the gate.
	for index: int in range(arrival_index + LONGEST_JUMP + 1, scenarios.size() - 1):
		if scenarios[index] in replaceable:
			candidates.append(index)

	var count: int = rng.randi_range(count_range.x, count_range.y)
	for i: int in range(mini(count, candidates.size())):
		var pick: int = rng.randi_range(0, candidates.size() - 1)
		scenarios[candidates[pick]] = station
		candidates.remove_at(pick)
	if count > 0:
		station.scenario_seed = rng.randi()


## Puts [param pilgrim] on one of the first few ordinary stops (anything in
## [param replaceable]) beyond a jump's reach of the arrival, from a generator
## of its own. Falls back to any ordinary stop right of the arrival in a sector
## too short for that. Static and pure, like place_repair_stations().
static func place_fate_pilgrim(
	scenarios: Array[ScenarioResource],
	arrival_index: int,
	replaceable: Array[ScenarioResource],
	pilgrim: ScenarioResource,
	placement_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed
	var early: Array[int] = []
	var later: Array[int] = []
	for index: int in range(arrival_index + 1, scenarios.size() - 1):
		if scenarios[index] not in replaceable:
			continue
		if index > arrival_index + LONGEST_JUMP and early.size() < 3:
			early.append(index)
		else:
			later.append(index)
	var pool: Array[int] = early if not early.is_empty() else later
	if pool.is_empty():
		return
	scenarios[pool[rng.randi_range(0, pool.size() - 1)]] = pilgrim
	pilgrim.scenario_seed = rng.randi()


## Swaps up to [param max_count] of [param consequences] (already filtered to
## those the run has earned) for ordinary stops ahead of the arrival in a
## finished sector. Like place_repair_stations() it uses its own generator and
## never draws from RUN, so a run that has earned none deals the map its seed
## always did.
##
## Anywhere ahead of the arrival, not only beyond a jump of it as stations
## are: a sector is short enough that that band, after the stations, often
## holds no ordinary stop at all, and an earned reckoning would silently not
## come. The arrival's neighbourhood only matters to the tutorial's sector 1,
## which is generated before the player has done anything. Ahead, it's on
## the map before the player gets there, to be met or flown around.
static func place_consequences(
	scenarios: Array[ScenarioResource],
	arrival_index: int,
	replaceable: Array[ScenarioResource],
	consequences: Array[ScenarioResource],
	max_count: int,
	placement_seed: int
) -> void:
	if consequences.is_empty() or max_count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed

	var candidates: Array[int] = []
	# The last slot is the gate.
	for index: int in range(arrival_index + 1, scenarios.size() - 1):
		if scenarios[index] in replaceable:
			candidates.append(index)

	var owed: Array[ScenarioResource] = consequences.duplicate()
	for i: int in range(mini(max_count, owed.size())):
		if candidates.is_empty():
			return
		var consequence: ScenarioResource = owed.pop_at(rng.randi_range(0, owed.size() - 1))
		var pick: int = rng.randi_range(0, candidates.size() - 1)
		scenarios[candidates[pick]] = consequence
		candidates.remove_at(pick)
		consequence.scenario_seed = rng.randi()


## Inserts [param count] more stops into a finished sector, the first
## [param event_count] of them events and the rest events at
## [param event_chance], otherwise fights. Each goes somewhere past a jump's
## reach of the arrival and before the gate, so the arrival's neighbourhood
## (which the tutorial scripts) stays as dealt. Prefers encounters neither
## [param dealt] (the sector as the seed dealt it) nor an earlier added stop
## holds: an event with none left becomes a fresh fight, and only once both
## run dry does a stop repeat.
##
## Static and pure, from its own generator like place_repair_stations(): it
## never draws from RUN, so the rest of a seeded map is dealt as before.
static func add_stops(
	scenarios: Array[ScenarioResource],
	dealt: Array[ScenarioResource],
	arrival_index: int,
	events: Array[ScenarioResource],
	combats: Array[ScenarioResource],
	count: int,
	event_count: int,
	event_chance: float,
	placement_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed
	var held: Array[ScenarioResource] = dealt.duplicate()
	for i: int in range(count):
		# Rolled every time, so a forced event doesn't shift later rolls.
		var event_roll: float = rng.randf()
		var want_event: bool = i < event_count or event_roll < event_chance
		var fresh_events: Array[ScenarioResource] = Utils.array_while_excluding(events, held)
		var fresh_combats: Array[ScenarioResource] = Utils.array_while_excluding(combats, held)
		var pool: Array[ScenarioResource] = fresh_events if want_event else fresh_combats
		if pool.is_empty():
			pool = fresh_combats if want_event else fresh_events
		var fresh: bool = not pool.is_empty()
		if not fresh:
			pool = events.duplicate()
			pool.append_array(combats)
		if pool.is_empty():
			return
		var stop: ScenarioResource = pool[rng.randi_range(0, pool.size() - 1)]
		# The gate is the last slot: insert anywhere up to just before it.
		var gate: int = scenarios.size() - 1
		var at: int = rng.randi_range(mini(arrival_index + LONGEST_JUMP + 1, gate), gate)
		scenarios.insert(at, stop)
		held.append(stop)
		# A repeat keeps the seed it was dealt with: the resource is shared.
		if fresh:
			stop.scenario_seed = rng.randi()


## One encounter from [param options], always spending exactly one draw of the
## RUN stream. RNGManager.pick_random() spends none on a single option
## (randi_range of one value doesn't roll), and each layer's lists are short
## enough to run down to one inside a sector, which would shift every later
## roll of a seeded map (the tutorial's included). For two or more options it
## picks exactly what pick_random() would.
static func _pick_one(options: Array[ScenarioResource]) -> ScenarioResource:
	return options[RNGManager.randi(RNGManager.Bucket.RUN) % options.size()]
