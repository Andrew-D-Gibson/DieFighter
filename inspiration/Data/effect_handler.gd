## EffectHandler
## ============================================================
## Base class for all concrete handler implementations.
##
## A handler's job is narrow: read EffectData + EffectContext, then either:
##   a) Modify the context (e.g. TargetEnemiesHandler populates context.targets)
##   b) Enqueue one or more EffectEvents into the engine
##   c) Both
##
## Handlers do NOT:
##   - Apply upgrades or modifiers (that's the engine's job)
##   - Directly mutate health, shields, or any game state
##   - Emit scenario signals (Events.*)
##
## Handlers ARE stateless — the same instance can be reused for every
## call with different data/context. This is why EffectRegistry stores
## a single handler instance per (category, subtype) pair.
##
## SUBCLASSING:
##   1. Extend EffectHandler.
##   2. Override apply().
##   3. Register in EffectRegistry._ready().
##
## EXAMPLE:
##   See inspiration/Handlers/deal_damage_handler.gd
## ============================================================

class_name EffectHandler
extends RefCounted


## Process one EffectData entry given the current context and engine.
## Override this in each concrete handler.
##
## 'data'    — the EffectData resource (may be a subclass like ConditionalEffectData)
## 'context' — mutable context; targeting handlers will write to context.targets
## 'engine'  — the live ScenarioEngine; call engine.enqueue_event() to queue work
func apply(_data: EffectData, _context: EffectContext, _engine: ScenarioEngine) -> void:
	pass  # Override in subclass.
