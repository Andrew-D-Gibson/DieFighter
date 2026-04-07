## EffectData
## ============================================================
## A single "step" in a data-driven effect chain.
## Author these as .tres Resource files in the Godot editor.
##
## Each EffectData describes ONE operation:
##   "Target all enemies"         → category=TARGETING, subtype=TARGET_ENEMIES
##   "Deal 3 damage"              → category=ATTRIBUTE_CHANGE, subtype=DAMAGE, amount=3
##   "Inherit damage from die"    → category=ATTRIBUTE_CHANGE, subtype=DAMAGE, inherit_die_amount=true
##   "Play the sword-hit sound"   → category=VISUAL, subtype=PLAY_SOUND, sound=<SFX resource>
##
## AUTHORING WORKFLOW:
##   1. Right-click in FileSystem → New Resource → EffectData.
##   2. Set 'category' to the correct Category enum value.
##   3. Set 'subtype' to the matching int (see EffectEnums for the values).
##      Until an EditorInspectorPlugin is written, you'll be typing raw int values.
##      Pin the EffectEnums script open in a second editor tab for reference.
##   4. Fill in the relevant parameter fields for your chosen subtype.
##      Fields that don't apply to your subtype are simply ignored.
##   5. Save the .tres and add it to an EffectChainV2's 'effects' array.
##
## PARAMETER FIELDS:
##   Not every field applies to every subtype. The handler for each
##   (category, subtype) pair reads only what it needs. Unused fields
##   are harmless and ignored.
##
## HOW TO KNOW WHICH FIELDS TO FILL:
##   Read the handler for your (category, subtype). The handler's apply()
##   method documents which fields it uses. Example:
##     DealDamageHandler reads: amount, inherit_die_amount
##     GainShieldsHandler reads: amount, inherit_die_amount
##     PlaySoundHandler reads:   sound_resource
##
## NOTE ON SUBTYPE INT VALUES:
##   The enum values in EffectEnums start at 0. So for TARGETING:
##     TARGET_ENEMIES = 0, TARGET_PLAYER = 1, TARGET_RANDOM_ENEMY = 2, ...
##   Check EffectEnums.gd for the exact ordering.
## ============================================================

class_name EffectData
extends Resource

# ── Identity ───────────────────────────────────────────────────────────────────

## What broad category of operation is this?
@export var category: EffectEnums.Category = EffectEnums.Category.TARGETING

## Which specific variant within the category?
## This is an int because GDScript can't export a conditionally-typed enum.
## Cross-reference EffectEnums.<Category>Subtype for the correct values.
@export var subtype: int = 0


# ── Numeric Parameters ─────────────────────────────────────────────────────────
## Used by: DAMAGE, HEAL, SHIELD, CHANGE_ENGINE_CHARGE, ADD_REPETITIONS,
##          ADD_USES_REMAINING, ADD_ADJACENT_TILES, INCREMENT_TILE_DATA,
##          CHANGE_ACTIVATOR_VALUE, WAIT (milliseconds), and others.

## The base numeric amount for this effect.
@export var amount: int = 0

## If true, the amount is taken from the activator die's face value at
## activation time instead of the fixed 'amount' field above.
## When inherit_die_amount is true, 'amount' is ignored.
## Used by: DAMAGE, HEAL, SHIELD, ADD_REPETITIONS, and similar.
@export var inherit_die_amount: bool = false

## Floating-point multiplier. Used by AMOUNT_MODIFIER/MULTIPLY.
@export var multiplier: float = 1.0


# ── String / Key Parameters ────────────────────────────────────────────────────
## Used by: INCREMENT_TILE_DATA, SET_TILE_DATA, PRINT_DEBUG.

## A string key used to look up or set named data on a tile.
## Example: tile.effect_data["charge_counter"]
@export var data_key: String = ""

## For PRINT_DEBUG: the message to print.
## For other uses: freeform string parameter.
@export var string_param: String = ""


# ── Vector Parameters ──────────────────────────────────────────────────────────
## Used by: MOVE_TILE_WITH_OFFSET.

## Grid offset (in tile units) for tile movement effects.
@export var grid_offset: Vector2i = Vector2i.ZERO


# ── Resource Parameters ────────────────────────────────────────────────────────
## Used by: PLAY_SOUND.

## The SFX resource to play. Used by VisualSubtype.PLAY_SOUND.
@export var sound_resource: Resource = null  # Type: SoundEffectResource


# ── Range Parameters ───────────────────────────────────────────────────────────
## Used by: ConditionalSubtype.IF_DIE_VALUE_IN_RANGE.

@export var range_min: int = 1
@export var range_max: int = 6
