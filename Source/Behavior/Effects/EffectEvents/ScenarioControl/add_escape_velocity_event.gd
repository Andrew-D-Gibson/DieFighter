class_name AddEscapeVelocityEvent
extends EffectEvent
## Charge for the Reckoning's escape, which is the engine charger itself
## (RECKONING_ENDINGS.md §1). Does nothing outside the Reckoning.


func resolve(_engine: ScenarioEngine) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	if director and amount != 0:
		director.add_escape_velocity(amount, effect_source as Node2D)
