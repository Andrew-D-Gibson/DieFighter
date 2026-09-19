class_name MoveShipEvent
extends EffectEvent

## Normalised position along the enemy path (0.0–1.0).
var position_proportion: float = 0.5


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor):
		return

	if actor == Globals.targeting_computer.targeted_enemy:
		Globals.targeting_computer.indicator_bob_tween.kill()
		Globals.targeting_computer.targeting_indicator.visible = false

	actor.graphics_manager.stop_bob_tween()
	actor.moving_in_world = true

	await Globals.enemy_manager.move_ship_to_point_on_path(actor, position_proportion)

	if not is_instance_valid(actor):
		return

	actor.moving_in_world = false
	actor.graphics_manager.start_bob_tween()

	if actor == Globals.targeting_computer.targeted_enemy:
		Globals.targeting_computer._move_indicator()
