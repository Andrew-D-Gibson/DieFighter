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

## The most slots one table may bind to another ship (an ally to help, a ship
## to raid). Each one adds a die face to the arc the targeting computer draws
## over the formation (BoundIntentArrow), and past three that badge crowds the
## ships around it. Extra ones are swapped out, see _cap_bound_slots().
const MAX_BOUND_SLOTS: int = 3

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
		actions.append(action.copy())
	var options: Array[EnemyActionOptionResource] = EnemyActionVariety.limit(
		available_options(pool, situation), situation, actions
	)

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
		_cap_bound_slots(actions, mini(forced.size(), SLOT_COUNT), options, weights)
		_ensure_hand_off(actions, mini(forced.size(), SLOT_COUNT), pool, situation)
		_unify_bound_slots(actions, mini(forced.size(), SLOT_COUNT), options, weights, situation)
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
	_cap_bound_slots(actions, mini(forced.size(), open_slots), options, weights)
	_ensure_hand_off(actions, mini(forced.size(), open_slots), pool, situation)
	_unify_bound_slots(actions, mini(forced.size(), open_slots), options, weights, situation)

	_place(actions, face_bias)
	# Ascending faces, so each insert lands at its face with the earlier ones
	# already in place.
	for face: int in kept_faces:
		var payoff: EnemyActionResource = kept_option.get_action()
		# A loader's amount was rolled (and scaled for run depth) when it was
		# shown, so the payoff keeps that promise instead of rolling anew.
		var loaded: int = situation.kept_amounts.get(face, 0)
		if loaded > 0:
			payoff.intent_amount = loaded
			payoff.amount_is_loaded = true
		actions.insert(face - 1, payoff)
	_number_slots(actions)
	return actions


## Swaps the bound slots of [param actions] past MAX_BOUND_SLOTS for draws
## from the options that bind nothing, before the table is placed on faces.
## The last ones drawn go first; the first [param keep] slots (the
## tutorial's) are never touched. With nothing unbound in the pool, the slot
## becomes a blank face.
static func _cap_bound_slots(
	actions: Array[EnemyActionResource],
	keep: int,
	options: Array[EnemyActionOptionResource],
	weights: Array[float]
) -> void:
	var bound: Array[int] = []
	for i: int in range(actions.size()):
		if actions[i].get_binding() != EnemyActionResource.Binding.NONE:
			bound.append(i)
	if bound.size() <= MAX_BOUND_SLOTS:
		return

	var excess: int = bound.size() - MAX_BOUND_SLOTS
	for k: int in range(bound.size() - 1, -1, -1):
		if excess == 0:
			break
		var slot: int = bound[k]
		if slot < keep:
			continue
		actions[slot] = _pick_unbound(options, weights)
		excess -= 1


## Makes every slot of [param actions] that acts on another ship (a Repair, a
## shield for an ally, a Raid, a Relay) the same action for the same amount:
## a ship does one thing to another ship a turn. The arc the targeting
## computer draws to that ship then carries one icon and one number beside
## the faces that play it (BoundIntentArrow), and only one arc leaves the
## ship, since the binder gives each kind of binding a single partner.
##
## The first bound slot sets the action, except that a hand-off a ship owes
## (_ensure_hand_off) always wins. Bound slots of another kind are swapped for
## draws that bind nothing, the way _cap_bound_slots trims extras; ones of the
## same kind take its amount. The first [param keep] slots (the tutorial's)
## are never touched, and one of them sets the action when it binds.
static func _unify_bound_slots(
	actions: Array[EnemyActionResource],
	keep: int,
	options: Array[EnemyActionOptionResource],
	weights: Array[float],
	situation: EnemyActionSituation
) -> void:
	var template: EnemyActionResource = _bound_template(actions, keep, situation)
	if template == null:
		return
	for i: int in range(keep, actions.size()):
		var action: EnemyActionResource = actions[i]
		if action == template or action.get_binding() == EnemyActionResource.Binding.NONE:
			continue
		# The same kind (EnemyActionVariety) aimed at the same kind of ship.
		if EnemyActionVariety.kind_of(action) == EnemyActionVariety.kind_of(template) \
				and action.get_binding() == template.get_binding():
			action.intent_amount = template.intent_amount
		else:
			actions[i] = _pick_unbound(options, weights)


## The bound slot whose action and amount the rest of the table's bound slots
## follow (see _unify_bound_slots()), or null when nothing binds.
static func _bound_template(
	actions: Array[EnemyActionResource],
	keep: int,
	situation: EnemyActionSituation
) -> EnemyActionResource:
	var first_bound: EnemyActionResource = null
	for i: int in range(actions.size()):
		var action: EnemyActionResource = actions[i]
		if action.get_binding() == EnemyActionResource.Binding.NONE:
			continue
		if i < keep:
			return action
		if first_bound == null:
			first_bound = action
		if situation.owes_hand_off and action.hands_off_to_hostile():
			return action
	return first_bound


## One weighted draw from the [param options] that bind no other ship. A blank
## face when there are none.
static func _pick_unbound(
	options: Array[EnemyActionOptionResource],
	weights: Array[float]
) -> EnemyActionResource:
	var unbound: Array[EnemyActionOptionResource] = []
	var unbound_weights: Array[float] = []
	var weight_sum: float = 0.0
	for n: int in range(options.size()):
		if options[n].base_action.get_binding() == EnemyActionResource.Binding.NONE:
			unbound.append(options[n])
			unbound_weights.append(weights[n])
			weight_sum += weights[n]
	return _weighted_pick(unbound, unbound_weights, weight_sum)


## Makes sure a ship that owes a hand-off (EnemyActionSituation.owes_hand_off)
## rolled one: if none of [param actions] passes its die on to a ship it
## fights, one slot is swapped for a draw from the pool's options that do.
## The first [param keep] slots (the tutorial's) are never touched. The draw
## ignores the variety cap, which can have trimmed the hand-off out; the
## table may then mix one kind more than the cap. It takes a bound slot when
## the table already holds MAX_BOUND_SLOTS, so it never adds one past that.
## A pool with no hand-off at all is left alone; the content tests keep any
## ship that can end up on the player's side from shipping without one.
static func _ensure_hand_off(
	actions: Array[EnemyActionResource],
	keep: int,
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation
) -> void:
	if not situation.owes_hand_off or actions.size() <= keep:
		return
	if actions.any(func(action: EnemyActionResource) -> bool: return action.hands_off_to_hostile()):
		return

	var hand_offs: Array[EnemyActionOptionResource] = []
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for option: EnemyActionOptionResource in available_options(pool, situation):
		if option.base_action.hands_off_to_hostile():
			hand_offs.append(option)
			weights.append(option.weight_in(situation))
			weight_sum += weights[-1]
	if hand_offs.is_empty():
		return

	var bound: Array[int] = []
	for i: int in range(keep, actions.size()):
		if actions[i].get_binding() != EnemyActionResource.Binding.NONE:
			bound.append(i)
	var slot: int = actions.size() - 1
	if bound.size() >= MAX_BOUND_SLOTS:
		slot = bound[-1]
	actions[slot] = _weighted_pick(hand_offs, weights, weight_sum)


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


## Rerolls one slot of [param actions] from the pool's options that bind no
## other ship. The binder's last resort for a relay it can't bind without
## closing a loop: it changes that one slot and nothing else the player can
## see. Nothing bound may land there, or the table could end up doing two
## things to other ships (see _unify_bound_slots()). The face is already
## fixed, so face_bias has no say in what lands there.
static func reroll_slot_without_relays(
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation,
	actions: Array[EnemyActionResource],
	slot: int
) -> void:
	var options: Array[EnemyActionOptionResource] = []
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	# The rest of the table stays, so this slot mustn't bring in a kind past
	# the cap.
	var others: Array[EnemyActionResource] = actions.duplicate()
	others.remove_at(slot)
	var allowed: Array[EnemyActionOptionResource] = EnemyActionVariety.within_table(
		available_options(pool, situation), situation, others
	)
	for option: EnemyActionOptionResource in allowed:
		if option.base_action.get_binding() != EnemyActionResource.Binding.NONE:
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
	# The soft shield cap: no piling shields on a ship that already holds as
	# many as its hull.
	if action.only_grants_shields():
		if action.get_binding() == EnemyActionResource.Binding.ALLY:
			if not situation.has_ally_under_shield_cap():
				return false
		elif situation.shields_capped:
			return false
	# A vent with nothing to vent would only ever pop a "?", so it's read off
	# the chain rather than left to each author to gate.
	if action.vents_own_statuses() and not situation.has_status():
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
	return _FALLBACK_ACTION.copy()


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
