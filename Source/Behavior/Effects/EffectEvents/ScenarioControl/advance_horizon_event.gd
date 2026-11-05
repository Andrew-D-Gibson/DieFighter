class_name AdvanceHorizonEvent
extends EffectEvent
## The Reckoning's event horizon comes [member amount] steps closer (Hunger).


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	if director:
		await director.advance_horizon(maxi(amount, 1))
