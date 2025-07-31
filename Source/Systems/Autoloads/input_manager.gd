extends Node

func _ready() -> void:
	# Make this unpausable so we can always quit out
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('PauseMenu'):
		Events.toggle_pause_menu.emit()
	elif event.is_action_pressed('EndTurn'):
		if len(Globals.player.dice_manager.queue) == 0:
			Globals.player.end_turn()
			
