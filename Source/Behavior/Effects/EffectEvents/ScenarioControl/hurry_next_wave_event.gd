class_name HurryNextWaveEvent
extends EffectEvent
## Hunger in the Reckoning (RECKONING_ENDINGS.md §1): the hole is hungry, and
## its next wave comes now, even if the one on the board isn't cleared. Does
## nothing outside the Reckoning.


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	if director:
		director.hurry_next_wave()
