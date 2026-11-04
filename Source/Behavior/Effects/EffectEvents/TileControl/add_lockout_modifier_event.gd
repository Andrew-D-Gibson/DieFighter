class_name AddLockoutModifierEvent
extends EffectEvent

## True when caused by an Asteroid Impact hazard, so the incoming rock flies
## in from off-screen onto the targeted tile right before the lock attaches.
var is_asteroid: bool = false

func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		if target is not Tile:
			continue
		var tile: Tile = target as Tile
		# Every lockout, from any enemy action or hazard, lands here, so this
		# is the one place the Engine Charger is protected (locking it could
		# leave the player with no way to charge the drive and leave), and the
		# backstop against a second lock on one tile, which the die that opens
		# it would fire twice. Random lockouts already skip both kinds of tile.
		if not tile.accepts_lockout():
			continue
		if is_asteroid:
			await HazardThematicVFX.play_asteroid_impact(tile)
			if engine.is_shut_down() or not is_instance_valid(tile):
				return
		var lockout: LockoutModifier = LockoutModifier.new(tile)
		lockout.source = effect_source as Node2D
		engine.add_modifier(lockout)
