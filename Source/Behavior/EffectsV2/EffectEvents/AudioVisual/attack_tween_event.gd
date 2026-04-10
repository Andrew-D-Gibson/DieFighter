class_name AttackTweenEvent
extends EffectEvent

var _tween_time: float = 1.25


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(actor):
		return

	var target_pos: Vector2 = targets[0].global_position
	var adjusted_time: float = _tween_time / Globals.animation_speed

	var tween: Tween = actor.create_tween().set_parallel(true)
	tween.tween_property(
		activator_die, "global_position", target_pos, adjusted_time
	).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_IN)
	tween.tween_property(
		activator_die, "rotation_degrees", 360.0 * 6.0, adjusted_time
	).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
