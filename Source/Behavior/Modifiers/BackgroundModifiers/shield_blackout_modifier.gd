class_name ShieldBlackoutModifier
extends Modifier
## No ship can raise shields while this is active.
##
## Ionized gas bleeds a shield capacitor flat as fast as it charges, so the
## whole shielding axis is simply off. Only shield *gains* are cancelled —
## effects that strip shields still land, because the point is that shielding
## is unavailable, not that shields are protected.


func _init() -> void:
	modifier_name = "Shield Blackout"
	priority = 5    # cancellation; runs before anything tries to scale it
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is ShieldEvent and event.amount > 0:
		event.canceled = true
