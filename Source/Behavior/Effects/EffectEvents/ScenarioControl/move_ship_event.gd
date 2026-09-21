class_name MoveShipEvent
extends EffectEvent

## Normalised position along the enemy path (0.0-1.0).
var position_proportion: float = 0.5


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor):
		return

	# EnemyManager owns the move itself: it pins the ship where this effect
	# asked for it, reflows the rest of the formation around the new gap, and
	# handles the bobbing idle and targeting reticle while the ship travels.
	await Globals.enemy_manager.move_ship_to_point_on_path(actor, position_proportion)
