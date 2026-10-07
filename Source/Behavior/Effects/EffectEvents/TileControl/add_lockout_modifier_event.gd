class_name AddLockoutModifierEvent
extends EffectEvent

func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		var lockout: LockoutModifier = LockoutModifier.new(target as Tile)
		lockout.source = effect_source as Node2D
		engine.add_modifier(lockout)
