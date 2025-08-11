extends Control

var main_menu_file: String = "uid://ccvtlre5vhj7d"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Events.game_over.connect(_on_game_over)
	Events.scenario_event.connect(func(event: ScenarioManager.ScenarioEvent) -> void:
		if event == ScenarioManager.ScenarioEvent.BOSS_DEFEATED:
			_on_game_win()
	)
	


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_file)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_game_over() -> void:
	%EndStateLabel.text = "[color=" + str(Globals.red.to_html(false)) + "]"\
	+ "[wave amp=30.0 freq=5.0 connected=1]"\
	+ "GAME OVER"\
	+ "[/wave][/color]"

	show()
	
	
func _on_game_win() -> void:
	%EndStateLabel.text = "[color=" + str(Globals.blue.to_html(false)) + "]"\
	+ "[wave amp=60.0 freq=10.0 connected=1]"\
	+ "VICTORY!"\
	+ "[/wave][/color]"
	
	show()
