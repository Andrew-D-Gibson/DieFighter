class_name AddUsesRemainingEvent
extends EffectEvent

## amount (from EffectEvent base) is the number of uses to add. Negative drains.

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
		# Unlimited tiles have no budget to top up or drain. Guarding it also
		# matters for drains: -1 means unlimited, so a spent tile drained
		# below 0 would otherwise come out able to fire forever.
		if target.uses_remaining == -1:
			continue
		target.uses_remaining = maxi(target.uses_remaining + amount, 0)
