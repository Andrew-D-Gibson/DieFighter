class_name HitstopEvent
extends EffectEvent

## amount is the freeze length in milliseconds. Awaited, so the chain holds on
## the impact frame and whatever comes after (the damage, the shake) lands as
## the game snaps back to speed.


## A duration, not an output — an Amplifier shouldn't lengthen the freeze.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	await TimeDirector.hitstop(roundi(amount / Globals.animation_speed))
