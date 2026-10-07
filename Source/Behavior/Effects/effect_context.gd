## EffectContext
## ============================================================
## Carries the "who and what" for an effect chain execution.
## Built by the caller (Tile.activate, enemy action scripts, etc.)
## and passed to EffectChain.play(context, engine).

class_name EffectContext
extends RefCounted


## The entity triggering this effect chain (player or enemy ship node).
var actor: Node = null

## The tile or enemy ship that owns this effect chain.
## Used for directional FX, targeting "effect source", etc.
var effect_source: Node = null

## The Dice node that was placed on the tile to trigger activation.
## May be null for non-die triggers (event responses, enemy actions, etc.).
var activator_die: Node = null  # Type: Dice

## The current set of targets. Targeting handlers populate this.
## Later handlers (damage, heal, shield) consume it.
## Each handler may replace or append to this list.
var targets: Array[Node] = []

## Before the chain's loop starts: how many times to loop the full effect
## chain (set by the caller, e.g. TileActivationEvent, then multiplied by
## EffectChain.base_repetitions and any repetition_conditions).
## Once the loop is running, EffectChain keeps this updated as an
## INFORMATIONAL "repetitions remaining after this one" counter only —
## the loop's actual iteration count is fixed before it starts and does NOT
## read this field back. Handlers may read it (e.g. "am I on the last
## repetition?") but must not rely on writing it to affect looping.
var repetitions: int = 1

## Running amount value, mutated by AMOUNT_MODIFIER handlers and consumed by ATTRIBUTE_CHANGE handlers.
## Reset to 0 at the start of each chain repetition.
var running_amount: int = 0

## Enemy intention, set by the enemy with an intent amount
var enemy_intent_amount: int = 0

## How many Feeds carried the activator die to this tile in the current chain.
## 0 means it arrived some other way (usually the player's hand). Lets a tile
## pay out for sitting at the end of a machine.
var feed_depth: int = 0

## The ship an enemy action was bound to when its slot was rolled (an ally to
## repair or feed, a civilian to raid). Read by the TARGET_BOUND_* steps.
## Null for anything that isn't an enemy action, or one that binds nothing.
var bound_target: Node = null
