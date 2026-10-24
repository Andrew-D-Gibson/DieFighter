class_name EnemyActionVariety
extends RefCounted
## Caps how many different kinds of action one ship's table may mix, so early
## sectors field ships that do one or two things and the full repertoire only
## turns up later in the run. See GameStateManager.action_kinds_per_sector.
##
## A kind is an action's name: every Dice Cannon is one kind whatever its
## amount, and a Shield Burst is another. Blank faces (Do Nothing) aren't a
## kind; they're the absence of one. Neither is a kept-face payoff (Siege
## Shot, Getaway): it only appears where the player chose to leave a die, so
## it isn't the ship's to vary.
##
## Which kinds make the cut is drawn fresh each turn, weighted by how many of
## the six slots each would have filled. A ship's signature action is usually
## kept, but anything it can do turns up now and then, so a capped ship still
## varies from turn to turn while each single table stays easy to read.


## The kind [param action] counts as, or "" for a blank face.
static func kind_of(action: EnemyActionResource) -> String:
	return action.name if action else ""


## [param options] trimmed to at most [member EnemyActionSituation.max_action_kinds]
## kinds, counting the kinds already in [param placed] (the tutorial's forced
## slots), which are never dropped. Options of a kind left out are dropped
## whole, force_include ones too. Returns [param options] untouched when there
## is no cap or nothing to trim, without drawing from the RNG, so such a roll
## is exactly what it would have been without the cap.
static func limit(
	options: Array[EnemyActionOptionResource],
	situation: EnemyActionSituation,
	placed: Array[EnemyActionResource] = []
) -> Array[EnemyActionOptionResource]:
	var cap: int = situation.max_action_kinds
	if cap <= 0:
		return options

	var kept: Array[String] = _kinds_in(placed)
	var shares: Dictionary[String, float] = _slot_shares(options, situation, placed.size())
	for kind: String in kept:
		shares.erase(kind)
	if kept.size() + shares.size() <= cap:
		return options

	while kept.size() < cap and not shares.is_empty():
		var kind: String = _draw(shares)
		kept.append(kind)
		shares.erase(kind)
	return _only_kinds(options, kept)


## [param options] cut down to what may fill one more slot of [param table]
## without taking it past the cap: anything while there's room for another
## kind, only the kinds already there once there isn't. For rerolling a single
## slot; pass the table without that slot.
static func within_table(
	options: Array[EnemyActionOptionResource],
	situation: EnemyActionSituation,
	table: Array[EnemyActionResource]
) -> Array[EnemyActionOptionResource]:
	var cap: int = situation.max_action_kinds
	var present: Array[String] = _kinds_in(table)
	if cap <= 0 or present.size() < cap:
		return options
	return _only_kinds(options, present)


## How many kinds [param actions] mixes.
static func count_kinds(actions: Array[EnemyActionResource]) -> int:
	return _kinds_in(actions).size()


static func _kinds_in(actions: Array[EnemyActionResource]) -> Array[String]:
	var kinds: Array[String] = []
	for action: EnemyActionResource in actions:
		var kind: String = kind_of(action)
		if not kind.is_empty() and kind not in kinds:
			kinds.append(kind)
	return kinds


## Roughly how many of the table's slots each kind would fill if nothing were
## capped: one for each force_include copy, plus its share of the weighted
## fill. Only the proportions matter, so kept faces are left out of the count.
static func _slot_shares(
	options: Array[EnemyActionOptionResource],
	situation: EnemyActionSituation,
	placed_count: int
) -> Dictionary[String, float]:
	var forced_count: int = 0
	var weight_sum: float = 0.0
	for option: EnemyActionOptionResource in options:
		if option.force_include:
			forced_count += 1
		weight_sum += option.weight_in(situation)
	var fill_slots: int = maxi(0, EnemyActionSelector.SLOT_COUNT - placed_count - forced_count)

	# Insertion order follows the pool, so a seeded roll draws the same way.
	var shares: Dictionary[String, float] = {}
	for option: EnemyActionOptionResource in options:
		var kind: String = kind_of(option.base_action)
		if kind.is_empty():
			continue
		var share: float = 1.0 if option.force_include else 0.0
		if weight_sum > 0.0:
			share += fill_slots * option.weight_in(situation) / weight_sum
		shares[kind] = shares.get(kind, 0.0) + share
	return shares


## One weighted draw of a kind. With every share at zero, the first kind.
static func _draw(shares: Dictionary[String, float]) -> String:
	var total: float = 0.0
	for share: float in shares.values():
		total += share
	if total <= 0.0:
		return shares.keys()[0]
	var threshold: float = RNGManager.randf_range(RNGManager.Bucket.ENEMY_AI, 0.0, total)
	for kind: String in shares:
		if shares[kind] > 0.0 and threshold <= shares[kind]:
			return kind
		threshold -= shares[kind]
	# Rounding can leave the draw just past the last kind.
	return shares.keys()[-1]


## The options of [param kinds], plus every blank one.
static func _only_kinds(
	options: Array[EnemyActionOptionResource],
	kinds: Array[String]
) -> Array[EnemyActionOptionResource]:
	var out: Array[EnemyActionOptionResource] = []
	for option: EnemyActionOptionResource in options:
		var kind: String = kind_of(option.base_action)
		if kind.is_empty() or kind in kinds:
			out.append(option)
	return out
