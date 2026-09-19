class_name AddLockoutModifierEvent
extends EffectEvent

func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		engine.add_modifier(LockoutModifier.new(target as Tile))
