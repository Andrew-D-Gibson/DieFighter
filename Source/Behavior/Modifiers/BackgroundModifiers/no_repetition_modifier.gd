class_name NoRepetitionModifier
extends Modifier
## Every tile activates exactly once, no matter what says otherwise.
##
## Clamps rather than cancels, so tiles still work — they just cannot be made
## to fire twice. Runs at clamping priority so it lands after the multipliers
## it is meant to overrule (ActivatesTwiceOnValueModifier and friends), which
## is the whole reason it is not simply a cancellation.


func _init() -> void:
	modifier_name = "No Repetition"
	priority = 75   # clamping; must run after the x2 multipliers at 50
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not TileActivationEvent:
		return

	var activation: TileActivationEvent = event as TileActivationEvent
	activation.activation_repetitions = mini(activation.activation_repetitions, 1)
