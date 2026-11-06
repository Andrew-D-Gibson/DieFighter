class_name CallAllyEvent
extends EffectEvent
## Mercy in the Reckoning (RECKONING_ENDINGS.md §1): the next ship the player
## saved jumps in now, or the one already aboard is healed and shielded for
## [member amount]. Does nothing outside the Reckoning.


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	if director:
		director.call_ally(amount)
