class_name ShakeDiceEvent
extends EffectEvent

## How long the shake lasts at normal animation speed. EffectData.amount
## sets it in milliseconds; zero keeps this default.
var duration_seconds: float = 1.2


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(actor):
		return

	var adjusted_time: float = duration_seconds / Globals.animation_speed
	var origin: Vector2 = activator_die.global_position

	var tween: Tween = actor.create_tween()
	tween.tween_property(activator_die, "global_position", origin + Vector2(2, 0), adjusted_time / 6.0)
	tween.tween_property(activator_die, "global_position", origin + Vector2(-2, 0), adjusted_time / 6.0)
	tween.tween_property(activator_die, "global_position", origin, adjusted_time * (4.0 / 6.0)) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await tween.finished
