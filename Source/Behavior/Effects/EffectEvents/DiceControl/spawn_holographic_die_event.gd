class_name SpawnHolographicDieEvent
extends EffectEvent

## amount is the hologram's face value, not a quantity.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return
	if amount <= 0:
		return
	Globals.player.spawn_dice(1, amount, true)
