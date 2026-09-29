class_name SlowMoEvent
extends EffectEvent

## amount is the slow-mo length in milliseconds of real time. Not awaited: the
## point is for the events after it to play out slowed.

var time_scale: float = 1.0


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	TimeDirector.slow_mo(time_scale, roundi(amount / Globals.animation_speed))
