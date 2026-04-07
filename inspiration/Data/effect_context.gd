## EffectContext
## ============================================================
## Carries the "who and what" for an effect chain execution.
##
## This replaces the old EffectVariables. Key difference:
##   - No modifier calculation logic here.
##   - No 'amount_modifiers' array.
##   - Modifiers live in the ScenarioEngine and act on EffectEvents.
##   - EffectContext is just plain context data — pure information carrier.
##
## Built by the caller (Tile.activate, enemy action scripts, etc.)
## and passed to EffectChainV2.play(context, engine).
##
## USAGE EXAMPLE (in Tile.activate):
##   var context := EffectContext.new()
##   context.actor = Globals.player
##   context.effect_source = self
##   context.activator_die = activator_die
##   effect_chain_v2.play(context, scenario_engine)
##   await scenario_engine.process_events()
## ============================================================

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

## How many times to loop the full effect chain.
## EffectChainV2 decrements this each loop; handlers should not touch it.
## Mirrors the old EffectVariables.repetitions behavior.
var repetitions: int = 1
