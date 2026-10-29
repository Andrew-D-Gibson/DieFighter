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

## Hull a stack of a status on the player is worth, beyond Burn (which is
## n + (n - 1) + ... + 1). Jammed throws away a die and hands it over;
## Exposed adds to the next hits; Scrambled only flips faces; Weakened takes
## a quarter off one turn of the player's own hits.
const _STATUS_STACK_COST: Dictionary[StringName, float] = {
	&"jammed": 3.5,
	&"exposed": 1.5,
	&"scrambled": 1.0,
	&"weakened": 1.5,
}


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
		var next: Enemy = action.bound_ship()
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


## The same dice with the highest turned to [param face] (Cryo Lance), the
## one ChangeHeldDiceEvent picks.
static func held_if_highest_set(ship: Enemy, face: int = 1) -> float:
	if not is_instance_valid(ship) or not ship.dice_manager:
		return 0.0
	var highest: Dice = ChangeHeldDiceEvent.highest_die(ship.dice_manager)
	var total: float = 0.0
	for die: Dice in ship.dice_manager.queue:
		if is_instance_valid(die):
			total += of_face(ship, face if die == highest else die.value, false)
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
			if _vents(action):
				var vented: float = 0.0
				var engine: ScenarioEngine = ScenarioEngine.current()
				if engine:
					for status: StatusModifier in engine.statuses_on(ship):
						vented += status_cost(status.status_id, status.stacks)
				return vented
			var applied: StringName = _status_applied(action)
			if not applied.is_empty():
				return status_cost(applied, action.intent_amount)
			# An attack worth its die's face authors no amount of its own.
			var amount: int = action.intent_amount if action.intent_amount > 0 else face
			# Weakened lasts out the ship's turn, so every die it spends is weakened.
			if _stacks(ship, &"weakened") > 0:
				amount = WeakenedStatus.weakened(amount)
			var hits: int = action.effect_chain.base_repetitions if action.effect_chain else 1
			return float(amount * maxi(hits, 1))
		EnemyActionResource.Threat.NEUTRAL:
			var cost: float = NEUTRAL_FLOOR + NEUTRAL_SHARE * action.intent_amount
			if _keeps_die(action):
				cost += KEPT_DIE
			return cost
	return 0.0


## The hull [param stacks] of Phased on the player would save: the biggest
## hits the dice the enemies already hold will throw at them, past any
## Phased already there (each stack lets the next hit through, but read as
## the biggest, which is what a cloak is played for).
static func phased_worth(stacks: int) -> float:
	if stacks <= 0 or not _intents_visible() or not is_instance_valid(Globals.enemy_manager):
		return 0.0
	var hits: Array[float] = []
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if not is_instance_valid(ship) or not ship.dice_manager:
			continue
		for die: Dice in ship.dice_manager.queue:
			if is_instance_valid(die):
				hits.append_array(_hits_of_face(ship, die.value))
	hits.sort()
	hits.reverse()
	var skip: int = 0
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine and is_instance_valid(Globals.player):
		var cloak: StatusModifier = engine.find_status(Globals.player, &"phased")
		skip = cloak.stacks if cloak else 0
	var worth: float = 0.0
	for i: int in range(skip, mini(skip + stacks, hits.size())):
		worth += hits[i]
	return worth


## Each hit [param ship]'s slot for [param face] throws at the player: one
## entry per shot of a plain attack, none for anything else.
static func _hits_of_face(ship: Enemy, face: int) -> Array[float]:
	var hits: Array[float] = []
	if face < 1 or face > ship.turn_actions.size() or ship.turn_actions[face - 1] == null:
		return hits
	var action: EnemyActionResource = ship.turn_actions[face - 1]
	if action.get_threat() != EnemyActionResource.Threat.DANGEROUS or not _acts(ship, face):
		return hits
	if _escapes(action) or _vents(action) or not _status_applied(action).is_empty():
		return hits
	var amount: int = action.intent_amount if action.intent_amount > 0 else face
	if _stacks(ship, &"weakened") > 0:
		amount = WeakenedStatus.weakened(amount)
	var shots: int = maxi(action.effect_chain.base_repetitions if action.effect_chain else 1, 1)
	for _shot: int in range(shots):
		hits.append(float(amount))
	return hits


## What [param stacks] of [param status_id] on the player will cost, in hull.
static func status_cost(status_id: StringName, stacks: int) -> float:
	if status_id == &"burn":
		return stacks * (stacks + 1) / 2.0
	return _STATUS_STACK_COST.get(status_id, 1.0) * stacks


## The status [param action] puts on the player, or &"" for none.
static func _status_applied(action: EnemyActionResource) -> StringName:
	if action.effect_chain == null:
		return &""
	for effect: EffectData in action.effect_chain.effects:
		if effect != null and effect.category == EffectEnums.Category.ATTRIBUTE_CHANGE \
		and effect.subtype == EffectEnums.AttributeChangeSubtype.APPLY_STATUS:
			return StringName(effect.string_param)
	return &""


static func _vents(action: EnemyActionResource) -> bool:
	return _has_step(action, EffectEnums.Category.ATTRIBUTE_CHANGE,
		EffectEnums.AttributeChangeSubtype.TRANSFER_STATUSES)


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
	return EnemyActionResource.outcome_of(ship.turn_actions[face - 1], ship) == EnemyActionResource.Outcome.ACTS


static func _stacks(ship: Enemy, status_id: StringName) -> int:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine:
		return 0
	var status: StatusModifier = engine.find_status(ship, status_id)
	return status.stacks if status else 0


static func _intents_visible() -> bool:
	return not is_instance_valid(Globals.state_manager) or Globals.state_manager.enemy_intents_visible()
