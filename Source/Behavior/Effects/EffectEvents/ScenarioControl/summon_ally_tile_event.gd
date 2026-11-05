class_name SummonAllyTileEvent
extends EffectEvent
## A ship the player saved flies into the Reckoning (Mercy).


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	if director:
		await director.summon_ally()
