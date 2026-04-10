class_name ActivateTargetedTilesEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		await target.try_to_activate()
