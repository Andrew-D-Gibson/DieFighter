class_name BackgroundFocus
extends Node
## What the game does while its window is in the background: it goes quiet
## (Mute in Background) and, mid-run, opens the pause menu (Pause in
## Background). OptionsSettings owns one and binds both options to it.
##
## The mute is an Amplify effect turned all the way down on the Master bus,
## not the bus's mute flag. Mute All owns that flag, so neither ever touches
## the other's state: whatever Mute All was is exactly what's there when focus
## comes back, and an options file saved while the window is in the
## background (quitting from the dock) never records a mute the player didn't
## choose.

## Low enough to be silence.
const _SILENT_DB: float = -80.0

var mute_in_background: bool = true:
	set(value):
		mute_in_background = value
		_update_silence()

var pause_in_background: bool = false

var _in_background: bool = false
## The Amplify effect on the Master bus while it's silenced, else null.
var _silencer: AudioEffectAmplify


func _ready() -> void:
	# Focus can be lost and regained while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	# Never leave the game silent behind us.
	_in_background = false
	_update_silence()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_in_background = true
			_update_silence()
			if pause_in_background and can_pause_game():
				Events.toggle_pause_menu.emit()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_in_background = false
			_update_silence()


## Whether the game is being kept quiet because it's in the background.
func is_silenced() -> bool:
	return _silencer != null


## Whether losing focus should open the pause menu: only during a run that's
## under way (never the main menu or a cutscene, which have no state
## manager, nor a finished run), not when something already paused the game,
## and not while the AutoPilot is playing.
func can_pause_game() -> bool:
	var state_manager: GameStateManager = Globals.state_manager
	if not is_instance_valid(state_manager) or not state_manager.is_inside_tree():
		return false
	if state_manager.state in [GameStateManager.GameState.GAME_OVER, GameStateManager.GameState.VICTORY]:
		return false
	if get_tree().paused:
		return false
	# The AutoPilot frees itself unless a QA run asked for it.
	return not (is_instance_valid(AutoPilot) and AutoPilot.is_playing())


func _update_silence() -> void:
	var silence: bool = _in_background and mute_in_background
	if silence == is_silenced():
		return
	var master: int = AudioServer.get_bus_index(&"Master")
	if silence:
		_silencer = AudioEffectAmplify.new()
		_silencer.volume_db = _SILENT_DB
		AudioServer.add_bus_effect(master, _silencer)
		return
	# Looked up rather than remembered by index, in case other effects were
	# added or removed in the meantime.
	for i: int in range(AudioServer.get_bus_effect_count(master) - 1, -1, -1):
		if AudioServer.get_bus_effect(master, i) == _silencer:
			AudioServer.remove_bus_effect(master, i)
	_silencer = null
