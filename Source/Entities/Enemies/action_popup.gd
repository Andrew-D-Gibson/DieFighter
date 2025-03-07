extends Node2D

@export var sprite: Sprite2D
var popup_time: float = 0.75

signal popup_finished()

func _ready() -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(2,2), popup_time).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Sprite2D, "modulate", Color(1,1,1,0.25), popup_time)
	tween.chain().tween_callback(func():
		popup_finished.emit()
		queue_free()
	)
