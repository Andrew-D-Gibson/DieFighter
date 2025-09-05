extends Node

func _ready() -> void:
	# Make this unpausable 
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	
func _unhandled_input(event: InputEvent) -> void:
	# Global actions
	if event.is_action_pressed("screenshot"):
		Events.take_screenshot.emit()
		
	# Game only actions
	if not Globals.state_manager or \
	Globals.state_manager.state == GameStateManager.GameState.GAME_OVER:
		return
		
	if event.is_action_pressed('PauseMenu'):
		Events.toggle_pause_menu.emit()
	elif event.is_action_pressed('EndTurn'):
		if len(Globals.player.dice_manager.queue) == 0:
			Globals.player.end_turn()
			
