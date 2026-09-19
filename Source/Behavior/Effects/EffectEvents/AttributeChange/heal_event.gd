class_name HealEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return

	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		target.health.change_health(amount)
