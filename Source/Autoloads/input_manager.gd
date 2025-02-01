extends Node

func _ready() -> void:
	# Make this unpausable so we can always quit out
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	
func _input(event: InputEvent) -> void:
	# Handle application quiting on "Esc"
	if event.is_action_pressed('PauseMenu'):
		get_tree().quit()
