class_name GlitchBurstEvent
extends EffectEvent

## amount is the glitch length in milliseconds of real time. Not awaited — the
## glitch runs over whatever happens next.


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	Events.glitch_burst.emit(roundi(amount / Globals.animation_speed))
