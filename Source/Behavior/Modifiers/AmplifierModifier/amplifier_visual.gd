class_name AmplifierVisual
extends Node2D


func _ready() -> void:
	var tween: Tween = get_tree().create_tween().set_loops()
	tween.tween_property(%ColorMod, "modulate:a", 0.3, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(%ColorMod, "modulate:a", 0.05, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
