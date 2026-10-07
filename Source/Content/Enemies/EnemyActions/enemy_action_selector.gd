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
## tutorial relies on their order.
static func roll(
	pool: EnemyTurnActionList,
	situation: EnemyActionSituation,
	forced: Array[EnemyActionResource] = []
) -> Array[EnemyActionResource]:
	var actions: Array[EnemyActionResource] = forced.slice(0, SLOT_COUNT)
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

	for i: int in range(SLOT_COUNT - actions.size()):
		actions.append(_weighted_pick(options, weights, weight_sum))

	RNGManager.shuffle_array(RNGManager.Bucket.ENEMY_AI, actions)
	_number_slots(actions)
	return actions


## Rerolls one slot of [param actions] from the pool's relay-free options.
## The binder's last resort for a relay it can't bind without closing a loop:
## it changes that one slot and nothing else the player can see.
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


static func is_available(option: EnemyActionOptionResource, situation: EnemyActionSituation) -> bool:
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
	var action: EnemyActionResource = _FALLBACK_ACTION.duplicate(true)
	action.intent_amount = 0
	return action


## Every action knows which face plays it, so its info text can say so.
static func _number_slots(actions: Array[EnemyActionResource]) -> void:
	for i: int in range(actions.size()):
		actions[i].activating_die_number = i + 1
