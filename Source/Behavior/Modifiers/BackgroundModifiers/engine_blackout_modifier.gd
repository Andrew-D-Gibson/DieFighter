class_name EngineBlackoutModifier
extends Modifier
## The player's engine cannot accumulate charge while this is active.
##
## Everything the drive produces goes into holding position against the well,
## so charge never builds. Only gains are cancelled — tiles that *spend* charge
## still work, so the player can burn what they arrived with and no more.


func _init() -> void:
	modifier_name = "Engine Blackout"
	priority = 5    # cancellation; runs before anything tries to scale it
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is ChangeEngineChargeEvent and event.amount > 0:
		event.canceled = true
