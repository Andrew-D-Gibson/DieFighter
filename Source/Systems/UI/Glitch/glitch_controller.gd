extends ColorRect

func _ready() -> void:
	_set_glitch(false)
	
	Events.set_glitch.connect(_set_glitch)
	
	
func _set_glitch(glitch_state: bool) -> void:
	show() if glitch_state else hide()
