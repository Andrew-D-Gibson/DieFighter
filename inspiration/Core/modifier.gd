## Modifier
## ============================================================
## Base class for all modifiers registered with a ScenarioEngine.
##
## A Modifier represents any persistent effect that can influence
## gameplay events: player upgrades, enemy passives, status effects,
## temporary buffs, curses, etc.
##
## Both player and enemy modifiers use this same class — the actor
## field on the event is how you distinguish whose modifier it is.
##
## PRIORITY SYSTEM:
##   Modifiers run in ascending priority order (lower number = earlier).
##   Use these suggested ranges to keep ordering predictable:
##
##     0 –  9  : Cancellation / immunity effects (run first, can stop everything)
##    10 – 29  : Additive flat modifiers (+N damage, +N shields)
##    30 – 49  : Conditional additive modifiers (+N if die is odd, etc.)
##    50 – 69  : Multiplicative modifiers (×2 damage)
##    70 – 89  : Clamping / cap effects (cap damage at 10)
##    90 – 99  : Follow-up enqueuers (gain shield when dealing damage)
##               These run last so they see the final resolved amount.
##
## SUBCLASSING:
##   1. Extend Modifier.
##   2. Set priority in _init() or as a field literal.
##   3. Override on_before_event() and/or on_after_event().
##   4. Use 'is' type checks to filter to the event types you care about.
##
## EXAMPLE:
##   See inspiration/Modifiers/double_damage_modifier.gd
##   See inspiration/Modifiers/shield_on_damage_modifier.gd
## ============================================================

class_name Modifier
extends RefCounted


## Lower priority runs first. See ranges above.
var priority: int = 50

## Human-readable name, useful for debug logs.
var modifier_name: String = "Unnamed Modifier"


# ── Hooks ──────────────────────────────────────────────────────────────────────

## Called before the event resolves.
## Use this to:
##   - Adjust event.amount  (e.g., event.amount += 2)
##   - Replace event.targets
##   - Cancel the event    (event.canceled = true)
##   - Enqueue a *replacement* event before this one resolves
##
## This is 'await'-safe: you can await animations here if needed,
## but most before-hooks will be instant math operations.
func on_before_event(_event: EffectEvent, _engine: ScenarioEngine) -> void:
	pass  # Override in subclass.


## Called after the event resolves (only called if the event was NOT canceled).
## Use this to:
##   - Enqueue follow-up events (e.g., "gain 1 shield when you deal damage")
##   - Track statistics / counters
##   - Apply status effects triggered by this event
##
## New events enqueued here are appended to the engine's queue and will be
## processed in order after the current event's after-hooks finish.
func on_after_event(_event: EffectEvent, _engine: ScenarioEngine) -> void:
	pass  # Override in subclass.
