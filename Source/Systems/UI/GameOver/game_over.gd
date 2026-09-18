extends Control

var main_menu_file: String = "uid://ccvtlre5vhj7d"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Events.game_over.connect(_on_game_over)
	# Keyed off victory, not BOSS_DEFEATED — there's a boss in every sector,
	# but only one end of the run.
	Events.victory.connect(_on_game_win)


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_file)


func _on_quit_button_pressed() -> void:
	QuitManager.request_quit()


func _on_game_over() -> void:
	%EndStateLabel.text = "[color=" + str(Globals.red.to_html(false)) + "]"\
	+ "[wave amp=30.0 freq=5.0 connected=1]"\
	+ "GAME OVER"\
	+ "[/wave][/color]"

	_show_run_summary(Globals.red)
	show()
	
	
func _on_game_win() -> void:
	%EndStateLabel.text = "[color=" + str(Globals.blue.to_html(false)) + "]"\
	+ "[wave amp=60.0 freq=10.0 connected=1]"\
	+ "VICTORY!"\
	+ "[/wave][/color]"

	_show_run_summary(Globals.blue)
	show()


## A run with nothing to say about it doesn't invite another one.
func _show_run_summary(tint: Color) -> void:
	if not Globals.run_stats:
		%RunSummaryLabel.text = ""
		return

	%RunSummaryLabel.text = "[center][color=%s]%s[/color][/center]" % [
		tint.darkened(0.25).to_html(false), Globals.run_stats.get_summary_text()
	]
