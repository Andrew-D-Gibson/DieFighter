extends ColorRect

func _ready() -> void:
	await get_tree().create_timer(2).timeout
	
	var tween: Tween = get_tree().create_tween()
	var reveal_time: float = 6
	var max_progress: float = 9
	
	tween.tween_property(
		self, 
		"material:shader_parameter/progress", 
		max_progress, 
		reveal_time
	).from(0)
