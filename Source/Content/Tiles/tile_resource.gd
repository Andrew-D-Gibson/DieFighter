class_name TileResource
extends Resource

@export_category('Info')
@export var tile_name: String
@export_multiline var activation_description: String
@export_multiline var description: String

enum Rarity {COMMON, UNCOMMON, RARE}
@export var rarity: Rarity = Rarity.COMMON
## Untick to hold a tile out of reward and shop offers while it's being
## reworked. It still loads everywhere else (dev console, saves), so it can be
## tested and a run that already owns it keeps working.
@export var offered_as_reward: bool = true

@export_category('Upgrade')
## The better version of this tile: its own TileResource beside this one, with
## is_upgrade ticked and offered_as_reward unticked. A copy of this tile
## dropped on one already on the grid merges into this. Null for a tile that
## can't be upgraded.
@export var upgraded_version: TileResource
## Ticked on an upgraded version: drawn with the upgrade shimmer and sparks.
@export var is_upgrade: bool = false

@export_category('Graphics')
@export var textures: SpriteFrames

@export_category('Behavior')
## Refilled at the start of every player turn. Set to -1 for infinite uses
@export var uses_per_turn: int
@export var activation_checks: Array[ActivationResource]

@export var effect_chain: EffectChain
@export var event_responses: Dictionary[TileEvent, EffectChain]

## A countdown tile counts down from this (dice on it, COUNT_DOWN, take
## their value off) and fires its ON_COUNTDOWN_ZERO response each time it
## runs out. 0 for a tile that doesn't count down. See TileCountdown.
@export_range(0, 99) var countdown: int = 0

## A twin-dice tile: its chain holds the first die (IF_SOURCE_HOLDS_DIE false
## -> KEEP_DIE_WITH_TILE) and pays out on the next. The hold spends no use,
## so a limited tile's use goes on the payout, and an echo skips the hold. A
## held die goes back to the hand when the turn ends, so it can't be banked.
@export var holds_first_die: bool = false

@export var dragging_allowed: bool = true

## Untick for a tile that must never be locked out. The Engine Charger is the
## one: it is the only way to charge the jump drive, so locking it could leave
## the player unable to ever leave. Lockouts refuse such a tile (see
## AddLockoutModifierEvent). Random lockouts already draw only from the grid,
## which the Engine Charger is never on; a grid tile with this unticked would
## need a lockable-only random pick, or a random lockout would fizzle on it.
@export var can_be_locked_out: bool = true

## This limit is ignored when the max dice allowed in queue is -1
@export var max_dice_in_queue: int = -1


## Whether this tile's chain hurts or debuffs the ship the targeting computer
## is on (damage, a status, stolen hull), as opposed to helping or only moving
## the die. Read off the chain, not authored, so it can't drift from what the
## tile does. Only steps after TARGET_WITH_TARGETING_COMPUTER count: a hit on
## "you" or on every enemy doesn't depend on which ship is targeted.
func hits_targeted_ship() -> bool:
	if _hits_targeted_ship < 0:
		var hits: bool = effect_chain != null and _chain_hits_targeted(effect_chain.effects, false)
		_hits_targeted_ship = 1 if hits else 0
	return _hits_targeted_ship == 1


## -1 until hits_targeted_ship() first works it out.
var _hits_targeted_ship: int = -1

const _AGGRESSIVE_SUBTYPES: Array[EffectEnums.AttributeChangeSubtype] = [
	EffectEnums.AttributeChangeSubtype.DAMAGE,
	EffectEnums.AttributeChangeSubtype.ION_DAMAGE,
	EffectEnums.AttributeChangeSubtype.BOUNTY_DAMAGE,
	EffectEnums.AttributeChangeSubtype.STEAL_HULL,
	EffectEnums.AttributeChangeSubtype.APPLY_STATUS,
	EffectEnums.AttributeChangeSubtype.TRANSFER_STATUSES,
	EffectEnums.AttributeChangeSubtype.MULTIPLY_STATUSES,
]


## [param aimed] is whether the targeting so far is the computer's ship.
static func _chain_hits_targeted(effects: Array[EffectData], aimed: bool) -> bool:
	for effect: EffectData in effects:
		if effect == null:
			continue
		if effect is ConditionalEffectData:
			var conditional: ConditionalEffectData = effect
			if _chain_hits_targeted(conditional.if_true_effects, aimed) \
					or _chain_hits_targeted(conditional.if_false_effects, aimed):
				return true
		elif effect.category == EffectEnums.Category.TARGETING:
			aimed = effect.subtype == EffectEnums.TargetingSubtype.TARGET_WITH_TARGETING_COMPUTER
		elif aimed and effect.category == EffectEnums.Category.ATTRIBUTE_CHANGE \
				and effect.subtype in _AGGRESSIVE_SUBTYPES:
			return true
	return false


## The name, in the current language, with its colour tag.
func display_name() -> String:
	return ContentText.text(self, &"tile_name")


## The activation line, in the current language, its {placeholders} filled
## from this tile's data. Empty when none was written.
func display_activation_description() -> String:
	return TextTokens.fill(ContentText.text(self, &"activation_description"), self)


## The description, in the current language, its {placeholders} filled from
## this tile's data (TextTokens) and its [data] counters still to be filled
## (Tile.fill_data_tokens).
func display_description() -> String:
	return TextTokens.fill(ContentText.text(self, &"description"), self)


## Numbers that live on the tile itself rather than on a step, for its text
## (TextTokens): {countdown} is where a countdown tile starts.
func _text_tokens() -> Dictionary:
	var own: Dictionary = {}
	if countdown > 0:
		own["countdown"] = countdown
	return own


func _content_text_prefix() -> String:
	return "TILE"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"tile_name", "NAME",
			"Name of a tile (a ship system the player puts dice on), title case. Heads its info panel, codex entry and shop card. Keep the [color] tag around it as written; a name ending in + is the upgraded version."),
		ContentText.Field.new(&"activation_description", "ACTIVATION",
			"Line above a tile's description in its info panel saying which dice it takes. Keep (die_N) tokens, {placeholders} and [color] tags as written."),
		ContentText.Field.new(&"description", "DESC",
			"What a tile does with the die put on it, in its info panel, codex entry and shop. Terse, and in the game's colour language: [color] tags, (die_N)/(keyword)/(icon) tokens, {placeholders} (the tile's numbers) and [data]...[/data] counters stay exactly as written, so the game can draw and fill them."),
	]
