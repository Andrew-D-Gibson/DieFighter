class_name AnimateDieToTileEvent
extends EffectEvent

## World-space position to tween the activator die toward.
## Populated by AnimateDieToTileHandler from the grid_offset + source tile position.
var target_global_pos: Vector2 = Vector2.ZERO

var _tween_time: float = 0.9


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return
	if not is_instance_valid(actor):
		return

	var adjusted_time: float = _tween_time / Globals.animation_speed
	var tween: Tween = actor.create_tween()
	tween.tween_property(
		activator_die, "global_position", target_global_pos, adjusted_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
