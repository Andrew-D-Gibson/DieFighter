@tool
class_name AmplifierVisual
extends Node2D


func _ready() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(%ColorMod, "modulate:a", 0.3, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(%ColorMod, "modulate:a", 0.05, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The amplified tile flares as the bonus lands. Drives self_modulate, since
## the idle breathing loop above owns modulate.
func on_modifier_triggered() -> void:
	var flare: Tween = create_tween()
	flare.tween_property(%ColorMod, "self_modulate", Color.WHITE, 0.3) \
		.from(Color(3.0, 3.0, 3.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Juice.sparkle(self, global_position + Vector2(0, 4), Globals.yellow, 6, 30.0, true)
