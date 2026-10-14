class_name EnemyActionSelector
extends RefCounted
## Rolls a ship's six intent slots from one of its action pools.
##
## The roll is the same weighted fill it always was. What's new is that an
## option can be gated out by the situation the ship is in: an action that
## would take the ship off the board can't be rolled into a table the player
## can't read. Whatever is rolled is still shown in full before the player
## commits a die.

## One slot per die face.
const SLOT_COUNT: int = 6

## What a slot gets when nothing in the pool is allowed. Handing the die back
## is the one thing that's always safe.
const _FALLBACK_ACTION: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")


## Rolls a full table. [param forced] actions (the tutorial's) take the first
## slots as given; when they fill the table it isn't shuffled, because the
## tutorial relies on their order. [param face_bias] is the ship's
## EnemyResource.face_bias: which faces its stronger actions lean toward.
static func roll(
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation,
	forced: Array[EnemyActionResource] = [],
	face_bias: float = 0.0
) -> Array[EnemyActionResource]:
	# Copies, because each slot gets numbered and bound: the tutorial's queued
	# resources are shared, and must not carry one ship's binding to the next.
	var actions: Array[EnemyActionResource] = []
	for action: EnemyActionResource in forced.slice(0, SLOT_COUNT):
		actions.append(action.duplicate(true))
	var options: Array[EnemyActionOptionResource] = available_options(pool, situation)

	# At least one of every "force_include" option, and the weights for the
	# weighted fill as the situation scales them.
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for option: EnemyActionOptionResource in options:
		if option.force_include:
			actions.append(option.get_action())
		weights.append(option.weight_in(situation))
		weight_sum += weights[-1]

	if actions.size() >= SLOT_COUNT:
		actions = actions.slice(0, SLOT_COUNT)
		_number_slots(actions)
		return actions

	# Kept faces are spoken for: the rest of the table is rolled and placed
	# around them, so a loaded die lands on its payoff and nothing else moves.
	var kept_option: EnemyActionOptionResource = _kept_face_option(pool, situation)
	var kept_faces: Array[int] = situation.kept_faces if kept_option else ([] as Array[int])
	var open_slots: int = SLOT_COUNT - kept_faces.size()

	for i: int in range(open_slots - actions.size()):
		actions.append(_weighted_pick(options, weights, weight_sum))
	actions = actions.slice(0, open_slots)

	_place(actions, face_bias)
	# Ascending faces, so each insert lands at its face with the earlier ones
	# already in place.
	for face: int in kept_faces:
		actions.insert(face - 1, kept_option.get_action())
	_number_slots(actions)
	return actions


## The pool's fills_kept_faces option this situation allows, or null. One is
## all a pool needs: every kept face gets a copy of it.
static func _kept_face_option(
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation
) -> EnemyActionOptionResource:
	if pool == null:
		return null
	for option: EnemyActionOptionResource in pool.actions_possible:
		if option and option.fills_kept_faces and _passes_gates(option, situation):
			return option
	return null


## Rerolls one slot of [param actions] from the pool's relay-free options.
## The binder's last resort for a relay it can't bind without closing a loop:
## it changes that one slot and nothing else the player can see. The face is
## already fixed, so face_bias has no say in what lands there.
static func reroll_slot_without_relays(
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation,
	actions: Array[EnemyActionResource],
	slot: int
) -> void:
	var options: Array[EnemyActionOptionResource] = []
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for option: EnemyActionOptionResource in available_options(pool, situation):
		if option.base_action.get_relay() != EnemyActionResource.Relay.NONE:
			continue
		options.append(option)
		weights.append(option.weight_in(situation))
		weight_sum += weights[-1]

	var action: EnemyActionResource = _weighted_pick(options, weights, weight_sum)
	action.activating_die_number = slot + 1
	actions[slot] = action


## The pool's options this situation allows.
static func available_options(
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation
) -> Array[EnemyActionOptionResource]:
	var options: Array[EnemyActionOptionResource] = []
	if pool == null:
		return options
	for option: EnemyActionOptionResource in pool.actions_possible:
		if is_available(option, situation):
			options.append(option)
	return options


## Whether [param option] can be rolled into an ordinary slot. Kept-face
## options never can: they only appear where a loaded die sits.
static func is_available(option: EnemyActionOptionResource, situation: EnemyActionSituation) -> bool:
	if option == null or option.fills_kept_faces:
		return false
	return _passes_gates(option, situation)


static func _passes_gates(option: EnemyActionOptionResource, situation: EnemyActionSituation) -> bool:
	if option == null or option.base_action == null:
		return false
	var action: EnemyActionResource = option.base_action
	if not situation.intents_visible and not action.is_safe_while_hidden():
		return false
	# An action that acts on another ship needs one there to bind to.
	match action.get_binding():
		EnemyActionResource.Binding.ALLY:
			if situation.allies.is_empty():
				return false
		EnemyActionResource.Binding.HOSTILE_SHIP:
			if situation.hostile_ships.is_empty():
				return false
	return option.conditions_met(situation)


## One weighted draw. Draws even when the weights sum to zero, the way the roll
## always has, so a pool with nothing gated out rolls exactly what it used to.
static func _weighted_pick(
	options: Array[EnemyActionOptionResource],
	weights: Array[float],
	weight_sum: float
) -> EnemyActionResource:
	var threshold: float = RNGManager.randf_range(RNGManager.Bucket.ENEMY_AI, 0, weight_sum)
	for i: int in range(options.size()):
		if threshold > weights[i]:
			threshold -= weights[i]
		else:
			return options[i].get_action()

	# Rounding can leave the draw just past the last option.
	if not options.is_empty():
		return options[-1].get_action()
	return _fallback()


static func _fallback() -> EnemyActionResource:
	return _FALLBACK_ACTION.duplicate(true)


## Orders a rolled table onto faces 1-6. With no bias it's the plain shuffle it
## has always been, draw for draw, so a seeded run rolls the same tables.
## Otherwise each action sorts on a random key nudged by how strong it is next
## to the rest of the table: strength only tilts the odds, so a strong action
## can still turn up on a face the bias leans away from.
static func _place(actions: Array[EnemyActionResource], face_bias: float) -> void:
	if is_zero_approx(face_bias):
		RNGManager.shuffle_array(RNGManager.Bucket.ENEMY_AI, actions)
		return

	var ranks: Array[float] = _strength_ranks(actions)
	var keyed: Array[Array] = []
	for i: int in range(actions.size()):
		var key: float = RNGManager.randf(RNGManager.Bucket.ENEMY_AI) + face_bias * ranks[i]
		keyed.append([key, actions[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i: int in range(keyed.size()):
		actions[i] = keyed[i][1]


## Each action's strength as its place in the table, from 0 (weakest) to 1
## (strongest). Ranks rather than raw strengths, so a bias tilts a table of
## shields the same amount as one of big guns. Equal strengths share the
## average of the places they span, so two identical attacks are treated alike.
static func _strength_ranks(actions: Array[EnemyActionResource]) -> Array[float]:
	var count: int = actions.size()
	var ranks: Array[float] = []
	ranks.resize(count)
	if count <= 1:
		ranks.fill(0.5)
		return ranks

	var strengths: Array[float] = []
	for action: EnemyActionResource in actions:
		strengths.append(action.placement_strength())
	var order: Array[int] = []
	for i: int in range(count):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return strengths[a] < strengths[b])

	var start: int = 0
	while start < count:
		var end: int = start
		while end + 1 < count and is_equal_approx(strengths[order[end + 1]], strengths[order[start]]):
			end += 1
		var shared: float = (start + end) / 2.0 / (count - 1)
		for k: int in range(start, end + 1):
			ranks[order[k]] = shared
		start = end + 1
	return ranks


## Every action knows which face plays it, so its info text can say so.
static func _number_slots(actions: Array[EnemyActionResource]) -> void:
	for i: int in range(actions.size()):
		actions[i].activating_die_number = i + 1
