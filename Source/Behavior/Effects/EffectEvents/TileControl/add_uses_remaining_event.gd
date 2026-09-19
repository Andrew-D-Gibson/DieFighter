class_name AddUsesRemainingEvent
extends EffectEvent

## amount (from EffectEvent base) is the number of uses to add.

func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		target.uses_remaining += amount
