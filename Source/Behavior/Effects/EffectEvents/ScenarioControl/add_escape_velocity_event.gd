class_name AddEscapeVelocityEvent
extends EffectEvent
## Charge for the Reckoning's escape: the Horizon Drive turns dice into it
## (LORE.md §7). Does nothing outside the Reckoning.


func resolve(_engine: ScenarioEngine) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	if director and amount != 0:
		director.add_escape_velocity(amount, effect_source as Node2D)
