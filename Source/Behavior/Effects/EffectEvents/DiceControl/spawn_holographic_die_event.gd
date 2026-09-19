class_name SpawnHolographicDieEvent
extends EffectEvent

func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return
	if amount <= 0:
		return
	Globals.player.spawn_dice(1, amount, true)
