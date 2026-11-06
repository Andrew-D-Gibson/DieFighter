extends Control


## How the run ended, if it ended one of Fate's ways (Events.fate_ending):
## &"escaped" or &"fell_in". Empty for an ordinary win or loss.
var _fate_ending: StringName = &""

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
	if _fate_ending == &"fell_in":
		%EndStateLabel.text = "[color=%s][shake rate=12 level=6 connected=1]%s[/shake][/color]" % [
			Globals.purple.to_html(false), tr("FATE_ENDING_FELL_IN_TITLE")]
		_show_run_summary(Globals.purple, tr("FATE_ENDING_FELL_IN_LINE"))
		show()
		return

	%EndStateLabel.text = "[color=" + str(Globals.red.to_html(false)) + "]"\
	+ "[wave amp=30.0 freq=5.0 connected=1]"\
	+ tr("GAME_OVER_TITLE")\
	+ "[/wave][/color]"

	_show_run_summary(Globals.red)
	show()
	
	
func _on_game_win() -> void:
	if _fate_ending == &"escaped":
		%EndStateLabel.text = "[color=%s][wave amp=40.0 freq=3.0 connected=1]%s[/wave][/color]" % [
			Globals.white.to_html(false), tr("FATE_ENDING_ESCAPED_TITLE")]
		_show_run_summary(Globals.white, _escape_epilogue())
		show()
		return

	%EndStateLabel.text = "[color=" + str(Globals.blue.to_html(false)) + "]"\
	+ "[wave amp=60.0 freq=10.0 connected=1]"\
	+ tr("GAME_OVER_VICTORY")\
	+ "[/wave][/color]"

	# The normal ending (LORE.md §8): the player takes the dead Bastion's
	# place, and the deal is theirs to keep.
	_show_run_summary(Globals.blue, tr("FATE_ENDING_FORWARD_LINE"))
	show()


## The secret ending's last words: the faces left on the die, and the ships
## that flew with the player at the end.
func _escape_epilogue() -> String:
	var lines: PackedStringArray = [tr("FATE_ENDING_ESCAPED_LINE")]
	var ledger: FateLedger = Globals.fate_ledger
	if ledger:
		var faces: PackedStringArray = []
		for face: FateDie.Face in FateDie.carvable_faces():
			var n: int = ledger.die.count(face)
			var res: FateFaceResource = FateFaceCatalog.get_face(face)
			if n > 0 and res:
				faces.append(res.coloured_name() + (" x%d" % n if n > 1 else ""))
		if not faces.is_empty():
			lines.append(tr("FATE_ENDING_FACES").format({"faces": "  ".join(faces)}))
		if not ledger.allies.is_empty():
			lines.append(tr_n(&"FATE_ENDING_ALLIES", &"FATE_ENDING_ALLIES_PLURAL", ledger.allies.size()).format({"n": ledger.allies.size()}))
	return "\n".join(lines)


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
