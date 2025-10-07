extends Control

var original_scale: Vector2

func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	original_scale = self.scale
	
	var angle_amount: int = 7
	var tween_time: float = 3
	
	await get_tree().create_timer(6).timeout
	
	var tween: Tween = get_tree().create_tween()
	#tween.tween_property(self, "rotation_degrees", -angle_amount, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	#tween.tween_property(self, "rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	#tween.tween_property(self, "rotation_degrees", angle_amount, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	#tween.tween_property(self, "rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "scale", original_scale * 1.15, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", original_scale, tween_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
