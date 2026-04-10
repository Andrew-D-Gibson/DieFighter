class_name SpawnHolographicDieEvent
extends EffectEvent

## amount (from EffectEvent base): number of holographic dice to spawn.
## die_value (from EffectEvent base): face value to spawn them with.

func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return
	if amount <= 0:
		return
	Globals.player.spawn_dice(amount, die_value, true)
