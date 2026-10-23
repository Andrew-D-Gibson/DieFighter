class_name EnemyActionResource
extends Resource

## How bad it is for the player that a die landed on this action. Drives the
## handover's body language: the tractor beam's color and the sound a die
## makes arriving, so a turn's worth of handovers reads before any intent does.
enum Threat {
	DEAD,      ## Does nothing to anyone — the die was wasted on them
	NEUTRAL,   ## Does something, but doesn't hurt the player directly
	DANGEROUS, ## Deals damage (ion damage to shields included)
}

## What kind of ship, if any, this action picks out when its slot is rolled.
enum Binding {
	NONE,
	ALLY,         ## Another ship on its own side (repair, feed)
	HOSTILE_SHIP, ## A ship its faction preys on, never the player (raid)
}

## Whether this action hands a die on to the ally it's bound to, who uses it
## at once. Relays are what can chain, so they're what the binder keeps from
## ever looping.
enum Relay {
	NONE,
	FEED,     ## Passes the die it was given; the face stays the same
	HOLOGRAM, ## Conjures a hologram whose face is the intent amount
}

## What spending a die on this action would come to right now. Unlike Threat,
## which is read off the chain once, this reads the board: the ship it was
## bound to may have died since, or the hangar may be full.
enum Outcome {
	ACTS,    ## Something in the game changes
	IDLE,    ## The action was never going to do anything (Do Nothing)
	BLOCKED, ## The action means to do something, but nothing it does can happen now
}

@export var name: String
@export_multiline var description: String
@export var indicator_texture: Texture2D
@export var info_texture: Texture2D
@export var effect_chain: EffectChain:
	set(value):
		effect_chain = value
		_derived.clear()

## Set by the EnemyActionOptionResource who creates this action.
## The raw rolled amount — used both for display (via get_intent_amount_text())
## and by effect_chain's "Set to Enemy Intent" amount modifier.
@export var intent_amount: int = 0


var activating_die_number: int:
	set(new_num):
		activating_die_number = clampi(new_num, 1, 6)

## The ship this slot acts on, chosen when the table is rolled so the intent
## can name it before the player commits a die. See EnemyTargetBinder.
var bound_target: Enemy = null

## Copied from the option that rolled this action. See
## EnemyActionOptionResource.strength_tier_override.
var strength_tier_override: float = -1.0

## What get_threat(), get_relay(), get_binding() and is_safe_while_hidden()
## read off the chain, kept once worked out: the binder and placement ask
## them for every slot of every ship. Cleared when the chain is replaced.
var _derived: Dictionary[StringName, int] = {}


## Text form of intent_amount for display, e.g. in (amount) description substitution.
## Blank when the action has no meaningful amount (e.g. a pure status effect).
func get_intent_amount_text() -> String:
	return str(intent_amount) if intent_amount != 0 else ''


## Read off the effect chain rather than authored, so it can't drift out of
## date with what the action actually does.
func get_threat() -> Threat:
	if not _derived.has(&"threat"):
		_derived[&"threat"] = Threat.DEAD if effect_chain == null else _threat_of(effect_chain.effects)
	return _derived[&"threat"] as Threat


## [param aimed_at_ship] is whether the steps before these last targeted
## another enemy ship (a raid's prey), whose damage is no threat to the player.
static func _threat_of(effects: Array[EffectData], aimed_at_ship: bool = false) -> Threat:
	var threat: Threat = Threat.DEAD
	for effect: EffectData in effects:
		if effect == null:
			continue
		if effect is ConditionalEffectData:
			var conditional: ConditionalEffectData = effect
			threat = maxi(threat, maxi(
				_threat_of(conditional.if_true_effects, aimed_at_ship),
				_threat_of(conditional.if_false_effects, aimed_at_ship)
			)) as Threat
		elif effect.category == EffectEnums.Category.TARGETING:
			aimed_at_ship = effect.subtype in [
				EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY,
				EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP,
			]
		elif effect.category == EffectEnums.Category.SCENARIO_CONTROL \
		and effect.subtype == EffectEnums.ScenarioControlSubtype.ESCAPE_WITH_DICE:
			# Losing dice for good is worse than any hit.
			return Threat.DANGEROUS
		elif effect.category == EffectEnums.Category.ATTRIBUTE_CHANGE \
		and effect.subtype in [EffectEnums.AttributeChangeSubtype.DAMAGE, EffectEnums.AttributeChangeSubtype.ION_DAMAGE]:
			# Ion only strips shields, but shields are what stand between a
			# hit and the hull, so losing them is a hurt all the same.
			if not aimed_at_ship:
				return Threat.DANGEROUS
			threat = maxi(threat, Threat.NEUTRAL) as Threat
		elif _has_consequence(effect):
			threat = maxi(threat, Threat.NEUTRAL) as Threat
	return threat


## How strong this action is, for placing it on a face (see
## EnemyActionSelector). Only the order matters: the threat tier first, then
## the rolled amount, so a 6-damage attack outranks a 3-damage one, and both
## outrank any shield. A hologram's amount is the face it conjures, not a
## measure of power, so it doesn't count.
func placement_strength() -> float:
	var tier: float = strength_tier_override
	if tier < 0.0:
		tier = float(get_threat())
	var amount: int = 0 if get_relay() == Relay.HOLOGRAM else intent_amount
	return tier * 100.0 + amount


## What spending a die on [param action] would come to right now. Jammed and
## the "?" pop-up both ask this one question, so a jam is never spent on a die
## that was going to fizzle anyway. An empty slot is idle.
static func outcome_of(action: EnemyActionResource) -> Outcome:
	if action == null:
		return Outcome.IDLE
	return action.get_outcome()


## See [enum Outcome]. Read fresh each time: unlike the chain, the board it
## depends on changes mid-turn.
func get_outcome() -> Outcome:
	if effect_chain == null:
		return Outcome.IDLE
	var tally: Dictionary[StringName, int] = {&"steps": 0, &"possible": 0}
	_tally_outcome(effect_chain.effects, false, tally)
	if tally[&"steps"] == 0:
		return Outcome.IDLE
	return Outcome.ACTS if tally[&"possible"] > 0 else Outcome.BLOCKED


## Counts the steps that would change the game, and how many of them still
## can. [param aimed_at_bound] is whether the targeting so far points at the
## bound ship. A conditional's branches are each counted from the aim going
## in; whichever branch runs, the steps after it keep that same aim.
func _tally_outcome(effects: Array[EffectData], aimed_at_bound: bool, tally: Dictionary[StringName, int]) -> void:
	for effect: EffectData in effects:
		if effect == null:
			continue
		if effect is ConditionalEffectData:
			var conditional: ConditionalEffectData = effect
			_tally_outcome(conditional.if_true_effects, aimed_at_bound, tally)
			_tally_outcome(conditional.if_false_effects, aimed_at_bound, tally)
			continue
		if effect.category == EffectEnums.Category.TARGETING:
			aimed_at_bound = effect.subtype in [
				EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY,
				EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP,
			]
			continue
		# A Feed changes nothing by itself for the threat reading, but handing
		# the die on is the whole point of the step.
		var is_feed: bool = effect.category == EffectEnums.Category.DICE_CONTROL \
			and effect.subtype == EffectEnums.DiceControlSubtype.FEED_ALLY
		if not is_feed and not _has_consequence(effect):
			continue
		tally[&"steps"] += 1
		if _step_can_happen(effect, aimed_at_bound):
			tally[&"possible"] += 1


func _step_can_happen(effect: EffectData, aimed_at_bound: bool) -> bool:
	var acts_on_bound: bool = aimed_at_bound or (
		effect.category == EffectEnums.Category.DICE_CONTROL
		and effect.subtype in [
			EffectEnums.DiceControlSubtype.FEED_ALLY,
			EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAM_FOR_ALLY,
		]
	)
	if acts_on_bound:
		# The ship was picked when the slot was rolled, and a slot is never
		# re-pointed: with it gone, this step has no one to act on.
		if not is_bound_target_present():
			return false
		if effect.category == EffectEnums.Category.ATTRIBUTE_CHANGE \
		and effect.subtype == EffectEnums.AttributeChangeSubtype.HEAL \
		and bound_target.health.health >= bound_target.health.max_health:
			return false
	if effect.category == EffectEnums.Category.SCENARIO_CONTROL \
	and effect.subtype == EffectEnums.ScenarioControlSubtype.LAUNCH_SHIP:
		var manager: EnemyManager = Globals.enemy_manager
		if manager != null and not manager.has_room_to_launch():
			return false
	return true


## Whether the ship this slot was bound to is still in the fight.
func is_bound_target_present() -> bool:
	return is_instance_valid(bound_target) and bound_target.health.health > 0


## Whether this action may sit in a table the player can't see yet. One that
## takes the ship off the board can't: a die handed to a ship whose intents
## read "?" would make it leave before the player could answer. Read off the
## chain for the same reason as get_threat().
func is_safe_while_hidden() -> bool:
	if not _derived.has(&"safe_while_hidden"):
		_derived[&"safe_while_hidden"] = int(_compute_safe_while_hidden())
	return bool(_derived[&"safe_while_hidden"])


func _compute_safe_while_hidden() -> bool:
	if effect_chain == null:
		return true
	return not _any_effect(effect_chain.effects, func(effect: EffectData) -> bool:
		return effect.category == EffectEnums.Category.SCENARIO_CONTROL \
			and effect.subtype in [
				EffectEnums.ScenarioControlSubtype.FLEE,
				EffectEnums.ScenarioControlSubtype.JUMP,
				EffectEnums.ScenarioControlSubtype.ESCAPE_WITH_DICE,
			]
	)


## Which kind of ship this action needs bound, read off its targeting steps.
## An action binds one ship at most; an ally takes precedence if a chain were
## ever authored with both.
func get_binding() -> Binding:
	if not _derived.has(&"binding"):
		_derived[&"binding"] = _compute_binding()
	return _derived[&"binding"] as Binding


func _compute_binding() -> Binding:
	if get_relay() != Relay.NONE or _targets_with(EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY):
		return Binding.ALLY
	if _targets_with(EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP):
		return Binding.HOSTILE_SHIP
	return Binding.NONE


func get_relay() -> Relay:
	if not _derived.has(&"relay"):
		_derived[&"relay"] = _compute_relay()
	return _derived[&"relay"] as Relay


func _compute_relay() -> Relay:
	if _has_step(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.FEED_ALLY):
		return Relay.FEED
	if _has_step(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAM_FOR_ALLY):
		return Relay.HOLOGRAM
	return Relay.NONE


## The face the relayed die shows when it reaches the ally, for a die of
## [param face] spent on this slot. 0 when nothing is relayed.
func relay_face(face: int) -> int:
	match get_relay():
		Relay.FEED:
			return face
		Relay.HOLOGRAM:
			return clampi(intent_amount, 1, 6)
	return 0


func _has_step(category: EffectEnums.Category, subtype: int) -> bool:
	if effect_chain == null:
		return false
	return _any_effect(effect_chain.effects, func(effect: EffectData) -> bool:
		return effect.category == category and effect.subtype == subtype
	)


func _targets_with(subtype: EffectEnums.TargetingSubtype) -> bool:
	return _has_step(EffectEnums.Category.TARGETING, subtype)


## Whether any step in the chain, either branch of a conditional included,
## satisfies [param test].
static func _any_effect(effects: Array[EffectData], test: Callable) -> bool:
	for effect: EffectData in effects:
		if effect == null:
			continue
		if test.call(effect):
			return true
		if effect is ConditionalEffectData:
			var conditional: ConditionalEffectData = effect
			if _any_effect(conditional.if_true_effects, test) \
			or _any_effect(conditional.if_false_effects, test):
				return true
	return false


## Whether a single step changes anything in the game. Targeting, visuals and
## passing the die along don't — every action does those, including the ones
## that do nothing.
static func _has_consequence(effect: EffectData) -> bool:
	match effect.category:
		EffectEnums.Category.TARGETING, \
		EffectEnums.Category.AUDIO_VISUAL, \
		EffectEnums.Category.AMOUNT_MODIFIER, \
		EffectEnums.Category.UTILITY:
			return false
		EffectEnums.Category.DICE_CONTROL:
			return effect.subtype not in [
				EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER,
				EffectEnums.DiceControlSubtype.GIVE_DIE_TO_TARGET,
				EffectEnums.DiceControlSubtype.GIVE_DIE_AWAY,
				EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR,
				EffectEnums.DiceControlSubtype.FEED_ALLY,
			]
		_:
			return true


func show_info() -> void:
	# Don't show info if this is a blank action
	if name == '':
		return

	var info: InfoResource = InfoResource.new()
	info.title_label_text = name

	if activating_die_number:
		info.bottom_label_text = "[color=yellow]Uses (die_%d) -> %s[/color]" % [
			activating_die_number, get_description_text()
		]
	else:
		info.bottom_label_text = get_description_text()

	info.texture = info_texture

	Events.show_info.emit(info)


## The description with this slot's rolled values filled in: (amount), and
## (target) for the ship it's bound to.
func get_description_text() -> String:
	var target_name: String = "another ship"
	if is_instance_valid(bound_target):
		target_name = bound_target.enemy_resource.enemy_name
	return description \
		.replace('(amount)', get_intent_amount_text()) \
		.replace('(target)', target_name)
