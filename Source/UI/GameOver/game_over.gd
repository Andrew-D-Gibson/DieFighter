extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Events.game_over.connect(func():
		visible = true
		get_tree().paused = true
	)
