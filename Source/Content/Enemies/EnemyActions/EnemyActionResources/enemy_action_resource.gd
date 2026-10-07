class_name EnemyActionResource
extends Resource

## How bad it is for the player that a die landed on this action. Drives the
## handover's body language: the tractor beam's color and the sound a die
## makes arriving, so a turn's worth of handovers reads before any intent does.
enum Threat {
	DEAD,      ## Does nothing to anyone — the die was wasted on them
	NEUTRAL,   ## Does something, but doesn't hurt the player directly
	DANGEROUS, ## Deals damage
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

@export var name: String
@export var description: String
@export var indicator_texture: Texture2D
@export var info_texture: Texture2D
@export var effect_chain: EffectChain

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


## Text form of intent_amount for display, e.g. in (amount) description substitution.
## Blank when the action has no meaningful amount (e.g. a pure status effect).
func get_intent_amount_text() -> String:
	return str(intent_amount) if intent_amount != 0 else ''


## Read off the effect chain rather than authored, so it can't drift out of
## date with what the action actually does.
func get_threat() -> Threat:
	if effect_chain == null:
		return Threat.DEAD
	return _threat_of(effect_chain.effects)


static func _threat_of(effects: Array[EffectData]) -> Threat:
	var threat: Threat = Threat.DEAD
	for effect: EffectData in effects:
		if effect == null:
			continue
		if effect is ConditionalEffectData:
			var conditional: ConditionalEffectData = effect
			threat = maxi(threat, maxi(
				_threat_of(conditional.if_true_effects),
				_threat_of(conditional.if_false_effects)
			)) as Threat
		elif effect.category == EffectEnums.Category.ATTRIBUTE_CHANGE \
		and effect.subtype == EffectEnums.AttributeChangeSubtype.DAMAGE:
			return Threat.DANGEROUS
		elif _has_consequence(effect):
			threat = Threat.NEUTRAL
	return threat


## Whether this action may sit in a table the player can't see yet. One that
## takes the ship off the board can't: a die handed to a ship whose intents
## read "?" would make it leave before the player could answer. Read off the
## chain for the same reason as get_threat().
func is_safe_while_hidden() -> bool:
	if effect_chain == null:
		return true
	return not _any_effect(effect_chain.effects, func(effect: EffectData) -> bool:
		return effect.category == EffectEnums.Category.SCENARIO_CONTROL \
			and effect.subtype in [
				EffectEnums.ScenarioControlSubtype.FLEE,
				EffectEnums.ScenarioControlSubtype.JUMP,
			]
	)


## Which kind of ship this action needs bound, read off its targeting steps.
## An action binds one ship at most; an ally takes precedence if a chain were
## ever authored with both.
func get_binding() -> Binding:
	if get_relay() != Relay.NONE or _targets_with(EffectEnums.TargetingSubtype.TARGET_BOUND_ALLY):
		return Binding.ALLY
	if _targets_with(EffectEnums.TargetingSubtype.TARGET_BOUND_HOSTILE_SHIP):
		return Binding.HOSTILE_SHIP
	return Binding.NONE


func get_relay() -> Relay:
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
		info.bottom_label_text = "[color=yellow]Enemy uses (die_" + \
									str(activating_die_number) + \
									") -> " + \
									get_description_text()
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

