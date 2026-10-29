class_name AutoPilotForecast
extends RefCounted
## What dropping a die on a tile would do, read off the tile's effect chain
## without running it, so a policy can weigh one move against another.
##
## The walk keeps the chain's own bookkeeping (targets, the running amount,
## repetitions) and asks the real handlers for the steps that only read the
## board: most targeting and most amount modifiers. Anything that would change
## the game is tallied here instead of queued. Random targets are spread evenly
## over the candidates rather than drawn, so a forecast never draws from a
## gameplay RNG bucket and a replay still plays the same.
##
## Echoes are followed: one already waiting, or one this move arms before its
## Feed, doubles the next tile the walk reaches.
##
## It's an estimate. Modifiers (amplifiers, statuses) aren't applied, a
## rerolled die's new face is unknown, and a tile activated without a die
## counts as a trick rather than being followed.

## How far a die is followed through Feeds.
const _MAX_FEED_DEPTH: int = 6
## How much of the payout a twin-dice hold is credited with, when a die in
## hand could pay it out: the hold and the payout die each claim half.
const _HOLD_PAYOUT_SHARE: float = 0.5
## The rest of a typical hand, when a tile on offer is valued without one:
## the dice that might pair with the one it holds.
const _NOMINAL_OTHER_DICE: float = 4.0
## How deep countdown payouts are followed into payouts they set off in turn.
const _MAX_PAYOUT_DEPTH: int = 2
## What the progress a count leaves toward the next payout is worth, as a
## share of that payout: it only pays if the fight lasts that long.
const _COUNTDOWN_PROGRESS_WORTH: float = 0.5

## What a payload put off for one turn is worth now, per turn it waits
## (DELAY_EFFECTS). Fights run two or three turns, so a late payoff may land
## on a ship already gone, or not at all.
const _DELAY_DISCOUNT_PER_TURN: float = 0.6

## Where a die, or a hologram, ends up with an enemy.
class Handoff:
	## null: a random ship.
	var ship: Enemy
	## 0: a face nobody knows yet (rerolled).
	var face: int
	## Destroyed on arrival, so harmless.
	var hologram: bool
	## The chance it goes there, when the destination was a random draw.
	var share: float = 1.0

## Expected damage by target: enemies, or the player. A shield given to an
## enemy counts as negative damage.
var damage: Dictionary[Node, float] = {}
## Net shields for the player, after any spent.
var shields: float = 0.0
var heal: float = 0.0
## Net engine charge, after any spent.
var charge: float = 0.0
## Stacks put on enemies, by status id.
var statuses: Dictionary[StringName, float] = {}
## Dice the player gets to play again: the activator handed back, holograms.
var dice_back: float = 0.0
var handoffs: Array[Handoff] = []
## Ships whose held dice get rerolled, flipped (1s and 6s), or taken back.
var rerolled: Array[Enemy] = []
var flipped: Array[Enemy] = []
var reclaimed: Array[Enemy] = []
## Map jump distance, signed.
var jump: int = 0
## Tiles activated, uses added, tiles moved, amplifiers laid: payoffs that
## land somewhere else.
var tile_tricks: float = 0.0
## How many Feeds the die went through.
var deepest_feed: int = 0
var destroys_itself: bool = false

## The ship standing in for the targeting computer's choice.
var _target: Enemy
## Every enemy a random draw could land on.
var _roster: Array[Enemy] = []
## Reads the board as if a fight were on, whatever the state: for valuing a
## tile with a stand-in enemy between fights.
var _as_in_a_fight: bool = false
## How many countdown payouts deep this forecast is (see _count_down()).
var _payout_depth: int = 0
## Echoes waiting for the next tile the walk reaches (EchoModifier).
var _echoes: int = 0
## Of those, how many this move armed itself.
var _echoes_armed: int = 0
## Set while walking a tile's answer to a status landing (Hex Coil), so an
## answer that applied a status itself couldn't set the walk going round.
var _answering_status: bool = false


## A forecast of [param die] dropped on [param tile] while [param target] is
## the targeted ship. [param roster] is the living enemies (default: the live
## game's). [param as_in_a_fight] reads the board as mid-fight, for valuing
## tiles against a stand-in enemy.
static func of(tile: Tile, die: Node, target: Enemy, roster: Array[Enemy] = [],
		as_in_a_fight: bool = false) -> AutoPilotForecast:
	var forecast := AutoPilotForecast.new()
	forecast._target = target
	forecast._roster = roster if not roster.is_empty() else _live_roster()
	forecast._as_in_a_fight = as_in_a_fight
	forecast._echoes = EchoModifier.armed_count(ScenarioEngine.current())
	var hologram: bool = die.get("holographic") == true
	var face: int = int(die.get("value"))
	# The player's own statuses act as the die lands: Scrambled flips it,
	# then Jammed (if the tile takes that face) sends it straight on.
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine and is_instance_valid(Globals.player) and JammedStatus.is_ship_system(tile):
		if engine.find_status(Globals.player, &"scrambled"):
			face = 7 - face
		if engine.find_status(Globals.player, &"jammed") and forecast._would_take(tile, face, hologram):
			forecast._jammed(target, face, hologram)
			return forecast
	forecast._follow(tile, die, face, hologram, 0, [])
	# An echo this move armed and nothing here spent pays off on a later tile.
	forecast.tile_tricks += float(mini(forecast._echoes_armed, forecast._echoes))
	return forecast


## A jammed tile does nothing; the die goes to the target, or home without one.
func _jammed(target: Enemy, face: int, hologram: bool) -> void:
	if not is_instance_valid(target):
		dice_back += 1.0
		return
	var handoff := Handoff.new()
	handoff.ship = target
	handoff.face = face
	handoff.hologram = hologram
	handoffs.append(handoff)


static func _live_roster() -> Array[Enemy]:
	if is_instance_valid(Globals.enemy_manager):
		return Globals.enemy_manager.get_alive_enemies()
	return []


## The chain's state as it walks: what a real EffectContext would hold, plus
## the face the die will show once the queued events resolve.
class _Walk:
	var context: EffectContext
	## Spread over context.targets when they came from a random draw.
	var share: float = 1.0
	## What the chain reads off the die while it walks. Events that change the
	## face only resolve after the chain has queued everything, so reads see
	## the face the die arrived with.
	var face: int
	## The face it leaves with, for wherever it goes next.
	var final_face: int
	var hologram: bool
	## Repetitions: amounts are multiplied, the die is disposed of once.
	var scale: int = 1
	## Set once something has decided where the die goes.
	var disposed: bool = false
	## Extra repetitions found while counting them.
	var extra_repetitions: int = 0
	var visited: Array[Tile] = []
	## The die the tile holds, for a payout the forecast is only imagining:
	## its face (0: none), or -1 to read the tile's real held die.
	var held_face: int = -1
	var held_hologram: bool = false


## [param held_face] imagines the tile holding a die of that face (see
## _Walk.held_face).
func _follow(tile: Tile, die: Node, face: int, hologram: bool, depth: int, visited: Array[Tile],
		held_face: int = -1, held_hologram: bool = false) -> void:
	deepest_feed = maxi(deepest_feed, depth)
	var chain: EffectChain = tile.tile_resource.effect_chain if tile.tile_resource else null
	if chain == null:
		return

	var walk := _Walk.new()
	walk.context = EffectContext.new()
	walk.context.actor = Globals.player
	walk.context.effect_source = tile
	walk.context.activator_die = die
	walk.context.feed_depth = depth
	# The last repetition is the one that hands the die on.
	walk.context.repetitions = 0
	walk.face = face
	walk.final_face = face
	walk.hologram = hologram
	walk.held_face = held_face
	walk.held_hologram = held_hologram
	walk.visited = visited.duplicate()
	walk.visited.append(tile)

	var repetitions: int = maxi(chain.base_repetitions, 1)
	for rule: ConditionalEffectData in chain.repetition_conditions:
		walk.context.running_amount = 0
		var rule_steps: Array[EffectData] = [rule]
		_run(rule_steps, walk)
	walk.scale = repetitions + walk.extra_repetitions
	if _echoes > 0 and _takes_echo(tile):
		_echoes -= 1
		_echoes_armed = mini(_echoes_armed, _echoes)
		walk.scale *= 2

	walk.context.running_amount = 0
	walk.context.targets = _none()
	walk.share = 1.0
	_run(chain.effects, walk)


## A fresh empty target list. Never clear() the context's own: a handler may
## have set it to an array the game still uses.
static func _none() -> Array[Node]:
	return []


func _run(effects: Array[EffectData], walk: _Walk) -> void:
	for data: EffectData in effects:
		if data == null:
			continue
		match data.category:
			EffectEnums.Category.TARGETING:
				_target_step(data, walk)
			EffectEnums.Category.AMOUNT_MODIFIER:
				_amount_step(data, walk)
			EffectEnums.Category.ATTRIBUTE_CHANGE:
				_attribute_step(data, walk)
			EffectEnums.Category.DICE_CONTROL:
				_dice_step(data, walk)
			EffectEnums.Category.TILE_CONTROL:
				_tile_step(data, walk)
			EffectEnums.Category.SCENARIO_CONTROL:
				if data.subtype == EffectEnums.ScenarioControlSubtype.JUMP:
					jump = walk.context.running_amount
					walk.disposed = true
			EffectEnums.Category.CONDITIONAL:
				var branching: ConditionalEffectData = data as ConditionalEffectData
				if branching:
					_run(branching.if_true_effects if _holds(branching, walk) else branching.if_false_effects, walk)
			EffectEnums.Category.REPETITION:
				walk.extra_repetitions += walk.context.running_amount
			EffectEnums.Category.UTILITY:
				if data.subtype == EffectEnums.UtilitySubtype.DESTROY_SOURCE:
					destroys_itself = true
				elif data.subtype == EffectEnums.UtilitySubtype.DELAY_EFFECTS:
					_delayed(data as DelayedEffectData, walk)


## A payload planted for a later turn (DELAY_EFFECTS), walked now against the
## same target and amount but discounted per turn of waiting: the fight may
## be over before it goes off.
func _delayed(delayed: DelayedEffectData, walk: _Walk) -> void:
	if delayed == null or walk.context.targets.is_empty():
		return
	var targets: Array[Node] = walk.context.targets.duplicate()
	var running: int = walk.context.running_amount
	var share: float = walk.share
	walk.share *= pow(_DELAY_DISCOUNT_PER_TURN, maxi(1, delayed.amount))
	_run(delayed.delayed_effects, walk)
	walk.context.targets = targets
	walk.context.running_amount = running
	walk.share = share


func _target_step(data: EffectData, walk: _Walk) -> void:
	walk.share = 1.0
	match data.subtype:
		EffectEnums.TargetingSubtype.TARGET_WITH_TARGETING_COMPUTER:
			var targeted: Array[Node] = []
			if is_instance_valid(_target):
				targeted.append(_target)
			walk.context.targets = targeted
		EffectEnums.TargetingSubtype.TARGET_RANDOM_ENEMY, \
		EffectEnums.TargetingSubtype.TARGET_RANDOM_OTHER_ENEMY:
			_spread(walk, _roster)
		EffectEnums.TargetingSubtype.TARGET_RANDOM_SHIP:
			var ships: Array[Node] = [Globals.player]
			ships.append_array(_roster)
			_spread(walk, ships)
		EffectEnums.TargetingSubtype.TARGET_RANDOM_TILE, \
		EffectEnums.TargetingSubtype.TARGET_RANDOM_LOCKABLE_TILE, \
		EffectEnums.TargetingSubtype.TARGET_RANDOM_ADJACENT_TILE:
			# Which tile is a draw; whatever it does lands on a tile, not a ship.
			walk.context.targets = _none()
			tile_tricks += 0.5
		_:
			var handler: EffectHandler = EffectRegistry.get_handler(data.category, data.subtype)
			if handler:
				handler.apply(data, walk.context, ScenarioEngine.current())


func _spread(walk: _Walk, candidates: Array) -> void:
	var targets: Array[Node] = []
	for candidate: Node in candidates:
		if is_instance_valid(candidate):
			targets.append(candidate)
	walk.context.targets = targets
	walk.share = 1.0 / targets.size() if not targets.is_empty() else 1.0


func _amount_step(data: EffectData, walk: _Walk) -> void:
	match data.subtype:
		EffectEnums.AmountModifierSubtype.SET_TO_DIE_VALUE:
			# An unknown face reads as a middling one.
			walk.context.running_amount = walk.face if walk.face > 0 else 3
		EffectEnums.AmountModifierSubtype.SET_RANDOM:
			walk.context.running_amount = roundi((data.range_min + data.range_max) / 2.0)
		EffectEnums.AmountModifierSubtype.ADD_HELD_DIE_VALUE:
			walk.context.running_amount += _held_face(walk)
		_:
			var handler: EffectHandler = EffectRegistry.get_handler(data.category, data.subtype)
			if handler:
				handler.apply(data, walk.context, ScenarioEngine.current())


func _attribute_step(data: EffectData, walk: _Walk) -> void:
	var amount: float = float(walk.context.running_amount * walk.scale)
	match data.subtype:
		EffectEnums.AttributeChangeSubtype.DAMAGE:
			for target: Node in walk.context.targets:
				if is_instance_valid(target):
					damage[target] = damage.get(target, 0.0) + amount * walk.share
		EffectEnums.AttributeChangeSubtype.HEAL:
			if _hits_player(walk):
				heal += amount * walk.share
		EffectEnums.AttributeChangeSubtype.SHIELD:
			for target: Node in walk.context.targets:
				if target == Globals.player:
					shields += amount * walk.share
				elif target is Enemy:
					damage[target] = damage.get(target, 0.0) - amount * walk.share
		EffectEnums.AttributeChangeSubtype.SPEND_SHIELDS:
			shields -= float(data.amount * walk.scale) if data.amount != 0 else amount
		EffectEnums.AttributeChangeSubtype.CHANGE_ENGINE_CHARGE, \
		EffectEnums.AttributeChangeSubtype.ADD_OVERCHARGE:
			charge += amount
		EffectEnums.AttributeChangeSubtype.SPEND_ENGINE_CHARGE, \
		EffectEnums.AttributeChangeSubtype.SIPHON_ENGINE_CHARGE:
			charge -= amount
		EffectEnums.AttributeChangeSubtype.APPLY_STATUS:
			var status: StringName = StringName(data.string_param)
			for target: Node in walk.context.targets:
				if target is Enemy:
					statuses[status] = statuses.get(status, 0.0) + amount * walk.share
					if amount > 0.0:
						_answer_status_applied(target, walk)
				elif target == Globals.player and status == &"burn":
					# Burn the player puts on themselves (Blowtorch) is hull
					# lost over the next turns, and stacks onto any Burn
					# already there: what it adds to n + (n - 1) + ... + 1.
					damage[target] = damage.get(target, 0.0) + _added_burn_cost(amount) * walk.share
		EffectEnums.AttributeChangeSubtype.MULTIPLY_STATUSES:
			# What it adds to the enemy's statuses as they stand now. A
			# repeat multiplies again, so each pass scales the last.
			var engine: ScenarioEngine = ScenarioEngine.current()
			if engine == null:
				return
			for target: Node in walk.context.targets:
				if target is not Enemy or not is_instance_valid(target):
					continue
				for status: StatusModifier in engine.statuses_on(target):
					var stacks: float = float(status.stacks)
					var grown: float = stacks * pow(maxf(data.multiplier, 1.0), walk.scale)
					statuses[status.status_id] = statuses.get(status.status_id, 0.0) \
						+ (grown - stacks) * walk.share
					if grown > stacks:
						_answer_status_applied(target, walk)


## Tallies what the grid's answers to a status landing on [param target]
## (ON_STATUS_APPLIED_TO_ENEMY: Hex Coil's hit) add, once per pass of the
## chain that applied it. Each answer starts aimed at that ship.
func _answer_status_applied(target: Node, walk: _Walk) -> void:
	if _answering_status or not is_instance_valid(Globals.tile_grid):
		return
	_answering_status = true
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		if not is_instance_valid(tile) or tile.tile_resource == null:
			continue
		for trigger: TileEvent in tile.tile_resource.event_responses:
			if trigger.event != TileEvent.EventType.ON_STATUS_APPLIED_TO_ENEMY:
				continue
			var answer := _Walk.new()
			answer.context = EffectContext.new()
			answer.context.actor = Globals.player
			answer.context.effect_source = tile
			answer.context.targets = [target] as Array[Node]
			answer.share = walk.share
			answer.scale = walk.scale
			# The answer has no die of its own to hand anywhere.
			answer.disposed = true
			_run(tile.tile_resource.event_responses[trigger].effects, answer)
	_answering_status = false


## Hull the player loses to Burn over the coming turns if [param added]
## stacks join the Burn already on them.
func _added_burn_cost(added: float) -> float:
	var engine: ScenarioEngine = ScenarioEngine.current()
	var burn: StatusModifier = engine.find_status(Globals.player, &"burn") if engine else null
	var now: float = float(burn.stacks) if burn else 0.0
	var after: float = now + added
	return (after * (after + 1.0) - now * (now + 1.0)) / 2.0


func _hits_player(walk: _Walk) -> bool:
	return Globals.player != null and walk.context.targets.has(Globals.player)


func _dice_step(data: EffectData, walk: _Walk) -> void:
	match data.subtype:
		EffectEnums.DiceControlSubtype.CHANGE_ACTIVATOR_VALUE:
			walk.final_face = clampi(walk.context.running_amount, 1, 6)
		EffectEnums.DiceControlSubtype.ADD_TO_ACTIVATOR_VALUE:
			if walk.final_face > 0:
				walk.final_face = clampi(walk.final_face + walk.context.running_amount, 1, 6)
		EffectEnums.DiceControlSubtype.SPLIT_ACTIVATOR:
			# The die leaves with the bigger half; the hologram is one more
			# die back in hand. A rerolled face may be a 1, which can't split.
			if walk.final_face != 1:
				dice_back += 1.0
			if walk.final_face > 0:
				walk.final_face = SplitActivatorEvent.halves(walk.final_face).x
		EffectEnums.DiceControlSubtype.REROLL_ACTIVATOR:
			walk.final_face = 0
		EffectEnums.DiceControlSubtype.FLIP_ONES_AND_SIXES:
			if walk.final_face == 1:
				walk.final_face = 6
			elif walk.final_face == 6:
				walk.final_face = 1
		EffectEnums.DiceControlSubtype.MERGE_HELD_DIE:
			var held_face: int = _held_face(walk)
			if held_face > 0 and walk.final_face > 0:
				walk.final_face = mini(walk.final_face + held_face, 6)
				dice_back += 1.0
		EffectEnums.DiceControlSubtype.GIVE_HELD_DIE_TO_TARGET:
			var held_face: int = _held_face(walk)
			if held_face > 0:
				if walk.context.targets.is_empty() or walk.context.targets[0] is Enemy:
					_hand_off(walk.context.targets, walk, held_face, _held_hologram(walk))
				else:
					dice_back += 1.0
		EffectEnums.DiceControlSubtype.GIVE_DIE_TO_TARGET:
			if not walk.disposed:
				walk.disposed = true
				if walk.context.targets.is_empty() or walk.context.targets[0] is Enemy:
					_hand_off(walk.context.targets, walk, walk.final_face, walk.hologram)
				else:
					# Given to the player: it stays on this side.
					dice_back += 1.0
		# Only an enemy gives dice away; a player's tile that tries keeps it.
		EffectEnums.DiceControlSubtype.GIVE_DIE_AWAY:
			walk.disposed = true
		EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER:
			if not walk.disposed:
				walk.disposed = true
				dice_back += 1.0
		EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_TILE:
			walk.disposed = true
			_value_hold(walk)
		EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR:
			walk.disposed = true
		EffectEnums.DiceControlSubtype.HOLD_DIE_FOR_TURNS:
			# Kept from the ships this turn and back in hand, face and all,
			# on a later one: worth something, though not a die to play now.
			if not walk.disposed:
				walk.disposed = true
				tile_tricks += 0.5
		EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAPHIC_DIE:
			dice_back += walk.scale
		EffectEnums.DiceControlSubtype.RECEIVE_DIE_FROM_TARGET:
			for target: Node in walk.context.targets:
				if target is Enemy and not reclaimed.has(target):
					reclaimed.append(target as Enemy)
		EffectEnums.DiceControlSubtype.REROLL_TARGETS_DICE:
			for target: Node in walk.context.targets:
				if target is Enemy and not rerolled.has(target):
					rerolled.append(target as Enemy)
		EffectEnums.DiceControlSubtype.FLIP_TARGETS_ONES_AND_SIXES:
			for target: Node in walk.context.targets:
				if target is Enemy and not flipped.has(target):
					flipped.append(target as Enemy)
		EffectEnums.DiceControlSubtype.REROLL_ALL:
			tile_tricks += 0.5


## The die goes to the first of [param targets], as GiveDieToTargetEvent
## sends it: to a random ship when they came from a random draw, and back to
## the hand when there's nobody to give it to.
func _hand_off(targets: Array[Node], walk: _Walk, face: int, hologram: bool) -> void:
	if targets.is_empty() or not is_instance_valid(targets[0]):
		dice_back += 1.0
		return
	var handoff := Handoff.new()
	handoff.ship = null if walk.share < 1.0 else targets[0] as Enemy
	handoff.face = face
	handoff.hologram = hologram
	handoffs.append(handoff)


func _tile_step(data: EffectData, walk: _Walk) -> void:
	match data.subtype:
		EffectEnums.TileControlSubtype.PASS_DIE_TO_TILE:
			if not walk.disposed:
				walk.disposed = true
				_feed(_feed_target(walk), walk, walk.final_face, walk.hologram)
		EffectEnums.TileControlSubtype.FEED_HOLOGRAM:
			_feed(_first_tile(walk), walk, clampi(walk.context.running_amount, 1, 6), true)
		EffectEnums.TileControlSubtype.ACTIVATE_TARGETED_TILES, \
		EffectEnums.TileControlSubtype.ADD_USES_REMAINING:
			tile_tricks += _tiles_in(walk)
		EffectEnums.TileControlSubtype.ACTIVATE_SELF, \
		EffectEnums.TileControlSubtype.ADD_AMPLIFIER_MODIFIER, \
		EffectEnums.TileControlSubtype.ADD_DEATH_SAVE_MODIFIER, \
		EffectEnums.TileControlSubtype.ADD_FAMILY_BOOST:
			tile_tricks += 1.0
		EffectEnums.TileControlSubtype.ARM_ECHO:
			# One per pass, each for a tile further down the line.
			_echoes += walk.scale
			_echoes_armed += walk.scale
		EffectEnums.TileControlSubtype.LOCKOUT_TILE:
			tile_tricks -= _tiles_in(walk)
		EffectEnums.TileControlSubtype.MOVE_TILE_WITH_OFFSET, \
		EffectEnums.TileControlSubtype.PUSH_TILE_IN_DIRECTION, \
		EffectEnums.TileControlSubtype.PUSH_TARGETED_TILES, \
		EffectEnums.TileControlSubtype.PULL_ROW_TILES_TO_COLUMN:
			tile_tricks += 0.25
		EffectEnums.TileControlSubtype.COUNT_DOWN:
			_count_down(walk)


## A COUNT_DOWN, valued as progress toward each target's payout: every payout
## it sets off now counts in full, and what it leaves toward the next counts
## at _COUNTDOWN_PROGRESS_WORTH of its share of one. So a die is worth its
## pips even when the count doesn't run out, and finishing one is worth more.
func _count_down(walk: _Walk) -> void:
	var amount: int = walk.context.running_amount * walk.scale
	if amount <= 0:
		return
	for target: Node in walk.context.targets:
		var tile: Tile = target as Tile
		if not is_instance_valid(tile) or not tile.is_countdown():
			continue
		var full: int = tile.tile_resource.countdown
		var left: int = tile.countdown_remaining() - amount
		var fires: int = 0
		var progress: int = amount
		if left <= 0:
			fires = 1 + (-left) / full
			left += fires * full
			progress = full - left
		var worth: float = fires + _COUNTDOWN_PROGRESS_WORTH * progress / full
		_add_payout(tile, worth * walk.share)


## Adds [param weight] times what [param tile]'s countdown payout would do.
func _add_payout(tile: Tile, weight: float) -> void:
	if _payout_depth >= _MAX_PAYOUT_DEPTH or weight <= 0.0:
		return
	var chain: EffectChain = null
	for response: TileEvent in tile.tile_resource.event_responses:
		if response.event == TileEvent.EventType.ON_COUNTDOWN_ZERO:
			chain = tile.tile_resource.event_responses[response]
	if chain == null:
		return

	var payout := AutoPilotForecast.new()
	payout._target = _target
	payout._roster = _roster
	payout._as_in_a_fight = _as_in_a_fight
	payout._payout_depth = _payout_depth + 1
	var walk := _Walk.new()
	walk.context = EffectContext.new()
	walk.context.actor = Globals.player
	walk.context.effect_source = tile
	walk.context.repetitions = 0
	walk.context.targets = _none()
	# A payout has no die of its own; the walk just reads no face.
	walk.face = 0
	walk.final_face = 0
	walk.visited = [tile] as Array[Tile]
	walk.scale = maxi(chain.base_repetitions, 1)
	payout._run(chain.effects, walk)
	_absorb(payout, weight)


## Whether an echo would repeat [param tile] (see EchoModifier.can_echo(); the
## die was already checked against it).
func _takes_echo(tile: Tile) -> bool:
	return tile.tile_resource.can_be_echoed \
		and not EchoModifier.repetitions_held(tile, ScenarioEngine.current())


## The tile a Feed goes to: the chain's own target, or, when it has none, the
## one the ship's rules aim it at (the Carousel's Reactor feeds its ignition
## slot through a modifier the forecast can't see).
func _feed_target(walk: _Walk) -> Tile:
	var next: Tile = _first_tile(walk)
	if next:
		return next
	var rules: Node = Globals.tile_grid.ship_behavior if Globals.tile_grid else null
	if rules and rules.has_method(&"feed_target_for"):
		return rules.feed_target_for(walk.context.effect_source, walk.final_face)
	return null


func _first_tile(walk: _Walk) -> Tile:
	for target: Node in walk.context.targets:
		if target is Tile and is_instance_valid(target):
			return target as Tile
	return null


func _tiles_in(walk: _Walk) -> float:
	var count: float = 0.0
	for target: Node in walk.context.targets:
		if target is Tile:
			count += 1.0
	return count * walk.share


## A Feed: the die (or a hologram) activates [param next] if that tile would
## take it, and goes to the targeted ship if not, as PassDieToTileEvent does.
func _feed(next: Tile, walk: _Walk, face: int, hologram: bool) -> void:
	if next and walk.context.feed_depth < _MAX_FEED_DEPTH and not walk.visited.has(next) \
	and _would_take(next, face, hologram):
		_follow(next, walk.context.activator_die, face, hologram, walk.context.feed_depth + 1, walk.visited)
		return
	# Nowhere to go on: PassDieToTileEvent gives it to the targeted ship.
	var targeted: Array[Node] = []
	if is_instance_valid(_target):
		targeted.append(_target)
	var direct := _Walk.new()
	_hand_off(targeted, direct, face, hologram)


## The face of the die the walk's tile holds, real or imagined; 0 for none.
func _held_face(walk: _Walk) -> int:
	if walk.held_face >= 0:
		return walk.held_face
	var tile: Tile = walk.context.effect_source as Tile
	var held: Dice = tile.get_held_die(walk.context.activator_die) if tile else null
	return held.value if held else 0


func _held_hologram(walk: _Walk) -> bool:
	if walk.held_face >= 0:
		return walk.held_hologram
	var tile: Tile = walk.context.effect_source as Tile
	var held: Dice = tile.get_held_die(walk.context.activator_die) if tile else null
	return held != null and held.holographic


## A twin-dice tile's hold pays nothing by itself. When a die in hand could
## pay it out, the hold is credited with a share of the best such payout, so
## the policy doesn't pass up a pair it's holding the makings of. Valuing a
## tile with a stand-in die (an offer, no hand to read), it's credited with
## the payout a typical hand would find a partner for. Only for a real hold:
## an imagined payout never values another hold, so this can't recurse.
func _value_hold(walk: _Walk) -> void:
	var tile: Tile = walk.context.effect_source as Tile
	if tile == null or not tile.tile_resource.holds_first_die or walk.held_face >= 0 \
	or walk.final_face <= 0 or _payout_depth >= _MAX_PAYOUT_DEPTH:
		return
	if walk.context.activator_die is not Dice:
		_value_nominal_hold(tile, walk)
		return
	if not is_instance_valid(Globals.player):
		return
	var best: AutoPilotForecast = null
	var best_damage: float = 0.0
	for partner: Dice in AutoPilotMove.dice_in_hand():
		if partner == walk.context.activator_die \
		or not _would_take(tile, partner.value, partner.holographic, walk.final_face):
			continue
		var payout: AutoPilotForecast = _imagine_payout(tile, partner, partner.value, partner.holographic, walk)
		var dealt: float = payout._damage_to_enemies()
		if best == null or dealt > best_damage:
			best = payout
			best_damage = dealt
	if best == null:
		return
	_absorb(best, _HOLD_PAYOUT_SHARE)
	# Both dice go somewhere on the payout, the held one included.
	for handoff: Handoff in best.handoffs:
		var share := Handoff.new()
		share.ship = handoff.ship
		share.face = handoff.face
		share.hologram = handoff.hologram
		share.share = handoff.share * _HOLD_PAYOUT_SHARE
		handoffs.append(share)


## The hold's share of a payout for a stand-in die: averaged over the faces
## that would pay it out, times the chance that one of the rest of a typical
## hand shows one of them.
func _value_nominal_hold(tile: Tile, walk: _Walk) -> void:
	var pairing: Array[int] = []
	for face: int in range(1, 7):
		if _would_take(tile, face, false, walk.final_face):
			pairing.append(face)
	if pairing.is_empty():
		return
	var miss: float = 1.0 - pairing.size() / 6.0
	var found: float = 1.0 - pow(miss, _NOMINAL_OTHER_DICE)
	var weight: float = _HOLD_PAYOUT_SHARE * found / pairing.size()
	for face: int in pairing:
		_absorb(_imagine_payout(tile, walk.context.activator_die, face, false, walk), weight)


## A forecast of [param partner] (showing [param face]) paying out the hold
## [param walk] is making on [param tile].
func _imagine_payout(tile: Tile, partner: Node, face: int, hologram: bool, walk: _Walk) -> AutoPilotForecast:
	var payout := AutoPilotForecast.new()
	payout._target = _target
	payout._roster = _roster
	payout._as_in_a_fight = _as_in_a_fight
	payout._payout_depth = _payout_depth + 1
	payout._follow(tile, partner, face, hologram, walk.context.feed_depth,
			walk.visited, walk.final_face, walk.hologram)
	return payout


func _damage_to_enemies() -> float:
	var total: float = 0.0
	for hit: Node in damage:
		if hit is Enemy:
			total += damage[hit]
	return total


## Adds [param weight] of [param other]'s outcome to this forecast: what it
## does, not where its dice go.
func _absorb(other: AutoPilotForecast, weight: float) -> void:
	for hit: Node in other.damage:
		damage[hit] = damage.get(hit, 0.0) + other.damage[hit] * weight
	for status: StringName in other.statuses:
		statuses[status] = statuses.get(status, 0.0) + other.statuses[status] * weight
	shields += other.shields * weight
	heal += other.heal * weight
	charge += other.charge * weight
	dice_back += other.dice_back * weight
	tile_tricks += other.tile_tricks * weight


## Tile.activation_refusal() for a die that may not be the one in hand: the
## checks that read the die read [param face] instead, and the ones that read
## the targeting computer read the ship this forecast is aimed at (a policy
## aims before it plays; between fights the computer holds nobody, and a
## stand-in enemy would read as no target at all).
##
## [param held_face] imagines the tile holding a die of that face, as
## _Walk.held_face does.
func _would_take(tile: Tile, face: int, hologram: bool, held_face: int = -1) -> bool:
	if tile.uses_remaining == 0:
		return false
	if held_face < 0:
		var held: Dice = tile.get_held_die()
		held_face = held.value if held else 0
	for check: ActivationResource in tile.tile_resource.activation_checks:
		match check.type:
			ActivationResource.ActivationType.MATCHES_HELD_DIE, \
			ActivationResource.ActivationType.SUMS_WITH_HELD_DIE:
				if held_face > 0 and (face <= 0 or not check.pairs_with(face, held_face)):
					return false
			ActivationResource.ActivationType.REQUIRES_ACTIVATOR_DIE:
				continue
			ActivationResource.ActivationType.VALUE:
				if face <= 0 or not face in check.acceptable_values:
					return false
			ActivationResource.ActivationType.ACTIVATOR_DIE_NOT_HOLOGRAPHIC:
				if hologram:
					return false
			ActivationResource.ActivationType.CANT_BE_ACTIVATED_WITH_DIE:
				return false
			ActivationResource.ActivationType.SHIP_TARGETED:
				if not is_instance_valid(_target):
					return false
			ActivationResource.ActivationType.OTHER_SHIPS_EXIST:
				if _roster.is_empty():
					return false
			ActivationResource.ActivationType.IN_COMBAT:
				if not _as_in_a_fight and not check.criteria_satisfied(null, tile):
					return false
			_:
				if not check.criteria_satisfied(null, tile):
					return false
	return true


## Whether a condition holds, reading the die's face from the walk (the die
## itself may not show it) and leaving the rest to ConditionalHandler.
func _holds(data: ConditionalEffectData, walk: _Walk) -> bool:
	match data.subtype:
		EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD:
			return walk.face % 2 != 0
		EffectEnums.ConditionalSubtype.IF_DIE_VALUE_IN_RANGE:
			return walk.face >= data.range_min and walk.face <= data.range_max
		EffectEnums.ConditionalSubtype.IF_TARGET_HOLDS_MATCHING_DIE:
			if walk.context.targets.is_empty() or not is_instance_valid(walk.context.targets[0]):
				return false
			var queue: DiceQueue = walk.context.targets[0].get("dice_manager") as DiceQueue
			return queue != null and queue.has_value(walk.face)
		EffectEnums.ConditionalSubtype.IF_SOURCE_HOLDS_DIE:
			return _held_face(walk) > 0
		EffectEnums.ConditionalSubtype.IF_TARGET_HAS_STATUS:
			var engine: ScenarioEngine = ScenarioEngine.current()
			return engine != null and not walk.context.targets.is_empty() \
				and is_instance_valid(walk.context.targets[0]) \
				and engine.find_status(walk.context.targets[0], StringName(data.string_param)) != null
	var handler: ConditionalHandler = EffectRegistry.get_handler(data.category, data.subtype) as ConditionalHandler
	return handler != null and handler._evaluate_condition(data, walk.context, ScenarioEngine.current())
