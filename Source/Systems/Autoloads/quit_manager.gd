extends Node

var _is_quitting: bool = false


func _ready() -> void:
	# Prevent the engine from quitting automatically when the window closes
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# User clicked the red X or pressed Alt+F4
		request_quit()


## Whether quitting means anything here. A browser tab is closed by the player,
## not the game, so a web build hides its Quit buttons.
static func can_quit() -> bool:
	return not OS.has_feature("web")


func request_quit() -> void:
	# External code should call this instead of get_tree().quit()
	if _is_quitting:
		return  # Avoid duplicate cleanup
	_is_quitting = true

	_cleanup_before_quit()
	get_tree().quit()


func _cleanup_before_quit() -> void:
	Globals.times_run += 1
	Events.save_options_config.emit()
