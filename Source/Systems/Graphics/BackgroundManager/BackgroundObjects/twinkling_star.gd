extends AnimatedSprite2D

func _ready() -> void:
	while true:
		var random_time: float = randf_range(3.0, 15.0)
		await get_tree().create_timer(random_time).timeout
		play("twinkle")
		await animation_finished
		play("default")
