## EffectHandler
## Base class for all concrete handler implementations.
##
## Handlers DO: 
##   a) Read EffectData + EffectContext
##   b) Modify the context (e.g. TargetEnemiesHandler populates context.targets)
##   c) Queue one or more EffectEvents into the engine if needed
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


class_name EffectHandler
extends RefCounted


## Process one EffectData entry given the current context and engine.
## Override this in each concrete handler.
##
## 'data'    — the EffectData resource (may be a subclass like ConditionalEffectData)
## 'context' — mutable context; targeting handlers will write to context.targets
## 'engine'  — the live ScenarioEngine; call engine.queue_event() to queue work
func apply(_data: EffectData, _context: EffectContext, _engine: ScenarioEngine) -> void:
	pass  # Override in subclass.
