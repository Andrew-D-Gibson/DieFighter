extends Sprite2D

@export var left_x: Sprite2D
@export var right_x: Sprite2D


func _ready() -> void:
	var tween_time: float = 6.0
	var left_bob_tween: Tween = create_tween()
	left_bob_tween.tween_property(left_x, 'position', Vector2(-8, 17), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	left_bob_tween.tween_property(left_x, 'position', Vector2(-8, 12), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	left_bob_tween.set_loops()

	var right_bob_tween: Tween = create_tween()
	right_bob_tween.tween_property(right_x, 'position', Vector2(8, 12), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	right_bob_tween.tween_property(right_x, 'position', Vector2(8, 17), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	right_bob_tween.set_loops()
