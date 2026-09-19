class_name RepairBlackoutModifier
extends Modifier
## No ship can repair hull while this is active.
##
## You cannot patch a hull that is being sandblasted. Only healing is
## cancelled; damage resolves normally, which is what makes the field
## frightening rather than merely inconvenient.


func _init() -> void:
	modifier_name = "Repair Blackout"
	priority = 5    # cancellation; runs before anything tries to scale it
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is HealEvent and event.amount > 0:
		event.canceled = true
