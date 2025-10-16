extends Node

var _is_quitting: bool = false

func _ready():
	# Prevent the engine from quitting automatically when the window closes
	get_tree().set_auto_accept_quit(false)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# User clicked the red X or pressed Alt+F4
		request_quit()


func request_quit():
	# External code should call this instead of get_tree().quit()
	if _is_quitting:
		return  # Avoid duplicate cleanup
	_is_quitting = true

	_cleanup_before_quit()
	get_tree().quit()


func _cleanup_before_quit():
	Globals.times_run += 1
	Events.save_options_config.emit()
