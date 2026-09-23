class_name AddUsesRemainingEvent
extends EffectEvent

## amount (from EffectEvent base) is the number of uses to add.

## Never amplified historically (its handler didn't pass effect_source, which
## Amplifier matches on). Return true to let an Amplifier grant extra uses.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		target.uses_remaining += amount
