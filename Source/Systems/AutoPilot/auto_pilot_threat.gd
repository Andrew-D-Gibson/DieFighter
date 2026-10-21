class_name AutoPilotThreat
extends RefCounted
## What a die will cost the player once an enemy spends it, in hull: the
## damage its intent promises, a smaller toll for anything else it does, and a
## steep one for a die the ship keeps or flies off with.
##
## Reads only what a player can see. While intents read "?" every face costs
## the same, and statuses are read the way their badges describe them.

## Any face of a ship whose intents are hidden: about what an average face of
## an average table costs. A hidden table can't make a ship leave, but it can
## still shoot (a shopkeeper's can).
const UNSEEN: float = 2.0

## An intent that acts but doesn't hurt (a shield, a heal, a buff): a share
## of its amount, plus a floor for the turn it buys the ship.
const NEUTRAL_SHARE: float = 0.4
const NEUTRAL_FLOOR: float = 0.5

## A die the ship keeps (Pilfer) is gone until the ship dies.
const KEPT_DIE: float = 4.0
## A ship escaping with dice takes every one it holds, for good.
const ESCAPE: float = 8.0
const ESCAPE_PER_DIE: float = 3.0


## The cost of handing [param ship] a die of [param face]. Face 0 means a face
## nobody knows yet (a rerolled die): the average over all six.
## [param arriving]: whether the die is still to arrive, so Scrambled will
## flip it and Jammed may swallow it. A die already held has been through both.
static func of_face(ship: Enemy, face: int, arriving: bool = true) -> float:
	if not _intents_visible():
		return UNSEEN
	if face <= 0:
		var total: float = 0.0
		for each: int in range(1, 7):
			total += of_face(ship, each, arriving)
		return total / 6.0
	if arriving:
		if _stacks(ship, &"scrambled") > 0:
			face = 7 - face
		# Jammed is only spent on dice that would act, so only those already
		# held queue ahead of this one for it.
		if _acts(ship, face) and _stacks(ship, &"jammed") > _held_acting_count(ship):
			return 0.0

	var cost: float = 0.0
	var visited: Array[Enemy] = []
	while is_instance_valid(ship) and not ship in visited:
		if face < 1 or face > ship.turn_actions.size() or ship.turn_actions[face - 1] == null:
			break
		var action: EnemyActionResource = ship.turn_actions[face - 1]
		cost += _cost_of_action(action, ship, face)
		var next: Enemy = action.bound_target
		if action.get_relay() == EnemyActionResource.Relay.NONE or not FeedAllyEvent.can_feed(next, []):
			break
		visited.append(ship)
		face = action.relay_face(face)
		ship = next
	return cost


## What the dice [param ship] already holds will cost when it spends them.
static func held(ship: Enemy) -> float:
	if not is_instance_valid(ship) or not ship.dice_manager:
		return 0.0
	var total: float = 0.0
	for die: Dice in ship.dice_manager.queue:
		if is_instance_valid(die):
			total += of_face(ship, die.value, false)
	return total


## The same dice, rerolled: each lands on a face nobody can call.
static func held_if_rerolled(ship: Enemy) -> float:
	if not is_instance_valid(ship) or not ship.dice_manager:
		return 0.0
	var count: int = 0
	for die: Dice in ship.dice_manager.queue:
		if is_instance_valid(die):
			count += 1
	return of_face(ship, 0, false) * count


## The same dice with every 1 and 6 swapped.
static func held_if_flipped(ship: Enemy) -> float:
	if not is_instance_valid(ship) or not ship.dice_manager:
		return 0.0
	var total: float = 0.0
	for die: Dice in ship.dice_manager.queue:
		if not is_instance_valid(die):
			continue
		var face: int = die.value
		if face == 1:
			face = 6
		elif face == 6:
			face = 1
		total += of_face(ship, face, false)
	return total


## The costliest die [param ship] holds: the one a player would take back.
static func worst_held(ship: Enemy) -> float:
	var worst: float = 0.0
	if not is_instance_valid(ship) or not ship.dice_manager:
		return worst
	for die: Dice in ship.dice_manager.queue:
		if is_instance_valid(die):
			worst = maxf(worst, of_face(ship, die.value, false))
	return worst


static func _cost_of_action(action: EnemyActionResource, ship: Enemy, face: int) -> float:
	match action.get_threat():
		EnemyActionResource.Threat.DANGEROUS:
			if _escapes(action):
				return ESCAPE + ESCAPE_PER_DIE * (_held_count(ship) + 1)
			# An attack worth its die's face authors no amount of its own.
			var amount: int = action.intent_amount if action.intent_amount > 0 else face
			var hits: int = action.effect_chain.base_repetitions if action.effect_chain else 1
			return float(amount * maxi(hits, 1))
		EnemyActionResource.Threat.NEUTRAL:
			var cost: float = NEUTRAL_FLOOR + NEUTRAL_SHARE * action.intent_amount
			if _keeps_die(action):
				cost += KEPT_DIE
			return cost
	return 0.0


static func _escapes(action: EnemyActionResource) -> bool:
	return _has_step(action, EffectEnums.Category.SCENARIO_CONTROL,
		EffectEnums.ScenarioControlSubtype.ESCAPE_WITH_DICE)


static func _keeps_die(action: EnemyActionResource) -> bool:
	return _has_step(action, EffectEnums.Category.DICE_CONTROL,
		EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR)


static func _has_step(action: EnemyActionResource, category: EffectEnums.Category, subtype: int) -> bool:
	if action.effect_chain == null:
		return false
	return EnemyActionResource._any_effect(action.effect_chain.effects, func(effect: EffectData) -> bool:
		return effect.category == category and effect.subtype == subtype
	)


static func _held_count(ship: Enemy) -> int:
	return ship.dice_manager.queue.size() if ship.dice_manager else 0


static func _held_acting_count(ship: Enemy) -> int:
	if not ship.dice_manager:
		return 0
	var count: int = 0
	for die: Dice in ship.dice_manager.queue:
		if is_instance_valid(die) and _acts(ship, die.value):
			count += 1
	return count


## Whether [param ship]'s slot for [param face] would do anything right now.
static func _acts(ship: Enemy, face: int) -> bool:
	if face < 1 or face > ship.turn_actions.size():
		return false
	return EnemyActionResource.outcome_of(ship.turn_actions[face - 1]) == EnemyActionResource.Outcome.ACTS


static func _stacks(ship: Enemy, status_id: StringName) -> int:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine:
		return 0
	var status: StatusModifier = engine.find_status(ship, status_id)
	return status.stacks if status else 0


static func _intents_visible() -> bool:
	return not is_instance_valid(Globals.state_manager) or Globals.state_manager.enemy_intents_visible()
