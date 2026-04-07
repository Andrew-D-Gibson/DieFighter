class_name Modifier
extends RefCounted

## Lower priority runs first
var priority: int = 50
##   Use these suggested ranges to keep ordering predictable:
##
##     0 –  9  : Cancellation / immunity effects (run first, can stop everything)
##    10 – 29  : Additive flat modifiers (+N damage, +N shields)
##    30 – 49  : Conditional additive modifiers (+N if die is odd, etc.)
##    50 – 69  : Multiplicative modifiers (×2 damage)
##    70 – 89  : Clamping / cap effects (cap damage at 10)
##    90 – 99  : Follow-up enqueuers (gain shield when dealing damage)
##               These run last so they see the final resolved amount.

## Human-readable name
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
