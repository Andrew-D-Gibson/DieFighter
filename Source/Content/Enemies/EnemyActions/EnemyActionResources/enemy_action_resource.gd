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
									description.replace('(amount)', get_intent_amount_text())
	else:
		info.bottom_label_text = description.replace('(amount)', get_intent_amount_text())

	info.texture = info_texture

	Events.show_info.emit(info)
