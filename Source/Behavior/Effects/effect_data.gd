@tool
## EffectData
## A single "step" in a data-driven effect chain.
## "Target all enemies", Deal 3 damage", "Play the dice roll sound"
##
## AUTHORING WORKFLOW:
##   1. Right-click in FileSystem → New Resource → EffectData.
##   2. Set 'category' to the correct Category enum value.
##   3. Set 'subtype' to the matching int
##   4. Fill in the parameter fields the inspector shows. Fields that don't
##      apply to your subtype are hidden, driven by EffectCatalog's 'fields'
##      entry for that effect.
##   5. Save the .tres and add it to an EffectChain's 'effects' array.

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
#
# Which fields apply is not decided here — EffectCatalog records, per effect,
# the fields its handler actually reads. Keeping that in one place is what
# stops an effect's only parameter from being invisible in the inspector,
# which is exactly what had happened to MOVE_SHIP's 'multiplier'.

func _validate_property(property: Dictionary) -> void:
	if property.name not in EffectCatalog.KNOWN_FIELDS:
		return
	if not EffectCatalog.uses_field(int(category), int(subtype), property.name):
		property.usage = PROPERTY_USAGE_NO_EDITOR
