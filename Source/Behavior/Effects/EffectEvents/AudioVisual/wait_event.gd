class_name WaitEvent
extends EffectEvent

## Queued enemy settles must use the action's playback speed, which may
## have increased since the ship queued its hand.
var scale_with_animation_speed: bool = false

## amount (from EffectEvent base) is the wait duration in milliseconds —
## a duration, not an output, so an Amplifier leaves it alone.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	if amount <= 0:
		return
	var seconds: float = amount / 1000.0
	if scale_with_animation_speed:
		seconds /= Globals.animation_speed
	await engine.get_tree().create_timer(seconds).timeout
