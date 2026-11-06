extends Control


## How the run ended, if it ended one of Fate's ways (Events.fate_ending):
## &"unlocked" (the first run to learn the secret, after its ending
## cutscene), or a Reckoning ending's id (ReckoningEnding.ending_id()).
## Empty for an ordinary win or loss.
var _fate_ending: StringName = &""

## Each Reckoning ending's card (RECKONING_ENDINGS.md §5-7): its title and
## closing line, and the colour they're set in.
const _RECKONING_CARDS: Dictionary[StringName, Dictionary] = {
	&"alone": {"title": "FATE_ENDING_ALONE_TITLE", "line": "FATE_ENDING_ALONE_LINE", "color": "white"},
	&"convoy": {"title": "FATE_ENDING_CONVOY_TITLE", "line": "FATE_ENDING_CONVOY_LINE", "color": "yellow"},
	&"last_die": {"title": "FATE_ENDING_LAST_DIE_TITLE", "line": "FATE_ENDING_LAST_DIE_LINE", "color": "yellow"},
	&"become_fate": {"title": "FATE_ENDING_BECOME_FATE_TITLE", "line": "FATE_ENDING_BECOME_FATE_LINE", "color": "purple"},
	&"fell_in": {"title": "FATE_ENDING_FELL_IN_TITLE", "line": "FATE_ENDING_FELL_IN_LINE", "color": "purple"},
}

## How tall one line of the run summary is, in this screen's pixels.
const _SUMMARY_LINE_HEIGHT: float = 34.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$VBoxContainer/QuitButton.visible = QuitManager.can_quit()

	Events.fate_ending.connect(func(kind: StringName) -> void: _fate_ending = kind)
	Events.game_over.connect(_on_game_over)
	# Keyed off victory, not BOSS_DEFEATED — there's a boss in every sector,
	# but only one end of the run.
	Events.victory.connect(_on_game_win)


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(SceneLoader.MAIN_MENU)


func _on_quit_button_pressed() -> void:
	QuitManager.request_quit()


func _on_wishlist_button_pressed() -> void:
	Utils.open_wishlist()


func _on_game_over() -> void:
	if _RECKONING_CARDS.has(_fate_ending):
		_show_reckoning_card()
		return

	%EndStateLabel.text = "[color=" + str(Globals.red.to_html(false)) + "]"\
	+ "[wave amp=30.0 freq=5.0 connected=1]"\
	+ tr("GAME_OVER_TITLE")\
	+ "[/wave][/color]"

	_show_run_summary(Globals.red)
	show()
	
	
func _on_game_win() -> void:
	if _RECKONING_CARDS.has(_fate_ending):
		_show_reckoning_card()
		return

	%EndStateLabel.text = "[color=" + str(Globals.blue.to_html(false)) + "]"\
	+ "[wave amp=60.0 freq=10.0 connected=1]"\
	+ tr("GAME_OVER_VICTORY")\
	+ "[/wave][/color]"

	if _fate_ending == &"unlocked":
		# The run that first learned the secret, after its ending cutscene
		# (EndingCutscene): it comes up out of black, so nothing of the game
		# shows behind it. The cutscene has said everything; no closing line.
		$ScreenDim.color.a = 1.0
		_show_run_summary(Globals.blue)
		show()
		return

	# The normal ending (LORE.md §8): the player reaches the front, and the
	# deal is theirs to keep.
	_show_run_summary(Globals.blue, tr("FATE_ENDING_FORWARD_LINE"))
	show()


## A Reckoning ending's card. It comes up out of the film's black, so
## nothing of the fight shows behind it (as after the first ending).
func _show_reckoning_card() -> void:
	var card: Dictionary = _RECKONING_CARDS[_fate_ending]
	var tint: Color = Globals.get(str(card["color"])) as Color
	var effect: String = "shake rate=12 level=6" if _fate_ending == &"fell_in" else "wave amp=40.0 freq=3.0"
	%EndStateLabel.text = "[color=%s][%s connected=1]%s[/%s][/color]" % [
		tint.to_html(false), effect, tr(str(card["title"])), effect.get_slice(" ", 0)]
	$ScreenDim.color.a = 1.0
	_show_run_summary(tint, _reckoning_line(str(card["line"])))
	show()


## The card's closing line. The perfect Convoy, which left nobody behind
## anywhere, has its own.
func _reckoning_line(key: String) -> String:
	var ending: ReckoningEnding = ReckoningDirector.last_ending
	if ending != null and ending.ending_id() == _fate_ending and ending.perfect:
		return tr("FATE_ENDING_CONVOY_PERFECT_LINE")
	return tr(key)


## A run with nothing to say about it doesn't invite another one.
## [param epilogue] goes above the numbers: a closing line for how it ended.
func _show_run_summary(tint: Color, epilogue: String = "") -> void:
	if not Globals.run_stats:
		%RunSummaryLabel.text = "[center]%s[/center]" % epilogue if not epilogue.is_empty() else ""
		return

	var lead: String = ""
	if not epilogue.is_empty():
		lead = "[color=%s]%s[/color]\n" % [tint.to_html(false), epilogue]
		# The extra lines grow the summary up into the space under the title,
		# so the numbers stay where they always are, clear of the buttons.
		var label: RichTextLabel = %RunSummaryLabel
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.offset_top = label.offset_bottom - _SUMMARY_LINE_HEIGHT * (epilogue.count("\n") + 2)
	%RunSummaryLabel.text = "[center]%s[color=%s]%s[/color][/center]" % [
		lead, tint.darkened(0.25).to_html(false), Globals.run_stats.get_summary_text()
	]
