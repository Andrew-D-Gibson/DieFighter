extends Node2D

@export var sprite: Sprite2D
var popup_time: float = 2.25

signal popup_finished()

func _ready() -> void:
	var adjusted_tween_time: float = popup_time / Globals.animation_speed
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(2,2), adjusted_tween_time).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Sprite2D, "modulate", Color(1,1,1,0.25), adjusted_tween_time)
	tween.chain().tween_callback(func():
		popup_finished.emit()
		queue_free()
	)
