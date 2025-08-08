extends Control

func _ready() -> void:
	var angle_amount: int = 7
	var tween_time: float = 1.5
	
	await get_tree().create_timer(4).timeout
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "rotation_degrees", -angle_amount, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", angle_amount, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_loops()
