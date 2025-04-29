extends Sprite2D

@export var left_x: Sprite2D
@export var right_x: Sprite2D


func _ready() -> void:
	var tween_time = 6
	var _left_bob_tween = get_tree().create_tween()
	_left_bob_tween.tween_property(left_x, 'position', Vector2(-8, 17), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_left_bob_tween.tween_property(left_x, 'position', Vector2(-8, 12), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_left_bob_tween.set_loops()
	
	var _right_bob_tween = get_tree().create_tween()
	_right_bob_tween.tween_property(right_x, 'position', Vector2(8, 12), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_right_bob_tween.tween_property(right_x, 'position', Vector2(8, 17), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_right_bob_tween.set_loops()
