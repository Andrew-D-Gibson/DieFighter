class_name ScreenShakeEvent
extends EffectEvent

## amount is the strength tier: 1 small, 2 large, 3 large with a glitch.
## The camera itself honours the screenshake accessibility setting.


## A strength tier, not an output — an Amplifier must not turn a small shake
## into a glitching one.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	match amount:
		1:
			Events.camera_shake_small.emit()
		2:
			Events.camera_shake_large.emit(false)
		_:
			Events.camera_shake_large.emit(true)
