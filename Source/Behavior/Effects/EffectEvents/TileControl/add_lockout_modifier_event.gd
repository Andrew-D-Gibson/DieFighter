class_name AddLockoutModifierEvent
extends EffectEvent

func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		var tile: Tile = target as Tile
		# Every lockout, from any enemy action or hazard, lands here, so this
		# is the one place the Engine Charger is protected. Locking it could
		# leave the player with no way to charge the drive and leave.
		if not tile.can_be_locked_out():
			continue
		var lockout: LockoutModifier = LockoutModifier.new(tile)
		lockout.source = effect_source as Node2D
		engine.add_modifier(lockout)
