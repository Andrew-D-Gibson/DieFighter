class_name SnapDieToPositionEvent
extends EffectEvent

## Internal-only event: not author-facing, has no EffectData/EffectHandler/
## registry entry. EffectChainV2 injects this directly between repetitions
## to reset the activator die's position — queuing it (rather than tweening
## inline) ensures it resolves in its correct sequential slot alongside the
## other events a repetition's effects injected (particles, damage, etc.),
## instead of running ahead of them.

var target_position: Vector2 = Vector2.ZERO


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(actor):
		return

	var tween: Tween = actor.create_tween()
	tween.tween_property(
		activator_die, "global_position", target_position, 0.06 / Globals.animation_speed
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
