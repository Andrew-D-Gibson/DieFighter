@tool
## EffectData
## A single "step" in a data-driven effect chain.
## "Target all enemies", Deal 3 damage", "Play the dice roll sound"
##
## AUTHORING WORKFLOW:
##   1. Right-click in FileSystem → New Resource → EffectData.
##   2. Set 'category' to the correct Category enum value.
##   3. Set 'subtype' to the matching int
##   4. Fill in the relevant parameter fields for your chosen subtype.
##      Fields that don't apply to your subtype are simply ignored.
##		Read the handler for your (category, subtype) to get the right fields.
##   5. Save the .tres and add it to an EffectChainV2's 'effects' array.

class_name EffectData
extends Resource

# ── Identity ───────────────────────────────────────────────────────────────────
## What broad category of operation is this?
## Changing category resets subtype to 0 and rebuilds the inspector.
@export var category: EffectEnums.Category = EffectEnums.Category.TARGETING:
	set(value):
		category = value
		subtype = 0
		notify_property_list_changed()
		emit_changed()

## Which specific variant within the category?
## The EditorInspectorPlugin replaces this with a labelled dropdown.
@export var subtype: int = 0:
	set(value):
		subtype = value
		notify_property_list_changed()
		emit_changed()

# ── Numeric Parameters ─────────────────────────────────────────────────────────
## The base numeric amount for this effect.
@export var amount: int = 0

## Floating-point multiplier. Used by AMOUNT_MODIFIER/MULTIPLY.
@export var multiplier: float = 1.0

# ── String / Key Parameters ────────────────────────────────────────────────────
## General-purpose string parameter.
## Used as the tile data key for INCREMENT_TILE_DATA and SET_TILE_DATA.
## Used as the message text for PRINT_DEBUG.
## Used as the key name for AMOUNT_MODIFIER subtypes that read tile data.
@export var string_param: String = ""


# ── Vector Parameters ──────────────────────────────────────────────────────────
## Grid offset (in tile units) for tile movement effects.
@export var grid_offset: Vector2i = Vector2i.ZERO


# ── Resource Parameters ────────────────────────────────────────────────────────
## The SFX resource to play. Used by AudioVisualSubtype.PLAY_SOUND.
@export var sound_resource: SoundEffectResource = null

## Particle tint color. Used by SPAWN_HIT_PARTICLES and SPAWN_EXPLOSION_PARTICLES.
@export var color: Color = Color.WHITE


# ── Range Parameters ───────────────────────────────────────────────────────────
## Used by: ConditionalSubtype.IF_DIE_VALUE_IN_RANGE.
@export var range_min: int = 1
@export var range_max: int = 6


# ── Inspector field visibility ─────────────────────────────────────────────────
# Hides fields that don't apply to the current (category, subtype) combination.
# Called automatically by Godot whenever notify_property_list_changed() fires.

func _validate_property(property: Dictionary) -> void:
	const CONDITIONAL_FIELDS: Array[String] = [
		"amount", "multiplier",
		"string_param", "grid_offset",
		"sound_resource", "color", "range_min", "range_max",
	]
	if property.name not in CONDITIONAL_FIELDS:
		return
	if not _should_show(property.name, int(category), int(subtype)):
		property.usage = PROPERTY_USAGE_NO_EDITOR


static func _should_show(prop: String, cat: int, sub: int) -> bool:
	match prop:
		"amount":
			match cat:
				EffectEnums.Category.AMOUNT_MODIFIER:
					return sub in [
						EffectEnums.AmountModifierSubtype.SET,
						EffectEnums.AmountModifierSubtype.ADD,
					]
				EffectEnums.Category.DICE_CONTROL:
					return sub in [
						EffectEnums.DiceControlSubtype.CHANGE_ACTIVATOR_VALUE,
						EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAPHIC_DIE,
					]
				EffectEnums.Category.AUDIO_VISUAL:
					return sub in [
						EffectEnums.AudioVisualSubtype.WAIT,
						EffectEnums.AudioVisualSubtype.SPAWN_HIT_PARTICLES,
						EffectEnums.AudioVisualSubtype.SPAWN_EXPLOSION_PARTICLES,
					]
				EffectEnums.Category.TILE_CONTROL:
					return sub in [
						EffectEnums.TileControlSubtype.ADD_USES_REMAINING,
						EffectEnums.TileControlSubtype.INCREMENT_TILE_DATA,
						EffectEnums.TileControlSubtype.SET_TILE_DATA,
					]
				EffectEnums.Category.REPETITION:
					return true
				_:
					return false
		"multiplier":
			return (cat == EffectEnums.Category.AMOUNT_MODIFIER
					and sub == EffectEnums.AmountModifierSubtype.MULTIPLY)
		"string_param":
			match cat:
				EffectEnums.Category.AMOUNT_MODIFIER:
					return sub in [
						EffectEnums.AmountModifierSubtype.ADD_ADJACENT_TILES,
						EffectEnums.AmountModifierSubtype.ADD_TILE_DATA,
					]
				EffectEnums.Category.TILE_CONTROL:
					return sub in [
						EffectEnums.TileControlSubtype.INCREMENT_TILE_DATA,
						EffectEnums.TileControlSubtype.SET_TILE_DATA,
					]
				EffectEnums.Category.UTILITY:
					return sub == EffectEnums.UtilitySubtype.PRINT_DEBUG
				_:
					return false
		"grid_offset":
			if cat == EffectEnums.Category.TARGETING:
				return sub in [
					EffectEnums.TargetingSubtype.TARGET_TILE_WITH_OFFSET
				]
			if cat == EffectEnums.Category.TILE_CONTROL:
				return sub in [
					EffectEnums.TileControlSubtype.MOVE_TILE_WITH_OFFSET,
					EffectEnums.TileControlSubtype.PUSH_TILE_IN_DIRECTION,
					EffectEnums.TileControlSubtype.PULL_ROW_TILES_TO_COLUMN
				]
			if cat == EffectEnums.Category.AUDIO_VISUAL:
				return sub == EffectEnums.AudioVisualSubtype.ANIMATE_DIE_TO_TILE
			return false
		"sound_resource":
			return (cat == EffectEnums.Category.AUDIO_VISUAL
					and sub == EffectEnums.AudioVisualSubtype.PLAY_SOUND)
		"color":
			return (cat == EffectEnums.Category.AUDIO_VISUAL and sub in [
				EffectEnums.AudioVisualSubtype.SPAWN_HIT_PARTICLES,
				EffectEnums.AudioVisualSubtype.SPAWN_EXPLOSION_PARTICLES,
			])
		"range_min", "range_max":
			return (cat == EffectEnums.Category.CONDITIONAL
					and sub == EffectEnums.ConditionalSubtype.IF_DIE_VALUE_IN_RANGE)
	return false
