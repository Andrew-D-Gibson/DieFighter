extends Camera2D

func _ready() -> void:
	Events.camera_shake_small.connect(func() -> void:
		if Globals.screenshake_enabled:
			$Shakeable.small_shake()
	)
	Events.camera_shake_large.connect(func() -> void:
		if Globals.screenshake_enabled:
			$Shakeable.large_shake()
	)
