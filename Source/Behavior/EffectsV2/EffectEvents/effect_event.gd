class_name EffectEvent
extends RefCounted


## The actor (player Node or Enemy Node) who triggered this effect.
## Used by modifiers to distinguish "player deals damage" from "enemy deals damage".
var actor: Node = null

## The tile or enemy ship that owns the effect chain being executed.
## Used for directional particle FX, range calculations, etc.
var effect_source: Node = null

## The Dice node that activated this effect (may be null for non-die effects).
var activator_die: Node = null  # Type: Dice

## Shortcut to the activator die's face value at the moment of activation.
## Stored here so modifiers can read it even after the die has moved/changed.
var die_value: int = 0

## The targets this event will affect. Set by targeting handlers,
## and can be overridden by modifiers in on_before_event().
var targets: Array[Node] = []

## The primary numeric amount for this event (damage dealt, shields gained,
## HP healed, etc.). Modifiers adjust this value in on_before_event().
var amount: int = 0

## Set to true by a modifier's on_before_event() to prevent resolution.
## Once canceled, no further before-hooks run, resolve() is skipped,
## and after-hooks are also skipped.
var canceled: bool = false

## Optional free-form metadata for handlers to attach extra data without
## subclassing. Prefer subclassing for anything non-trivial.
## Example: metadata["source_tile_position"] = Vector2(2, 3)
var metadata: Dictionary = {}


# ── Interface ──────────────────────────────────────────────────────────────────

## Override this in each concrete event class.
## The engine calls this after all before-hooks have run (and not canceled).
## Use 'await' here for animations, tweens, or any async work.
func resolve(_engine: ScenarioEngine) -> void:
	pass  # Base class no-op. Subclasses must override.
