extends ColorRect

## Bumped by every burst, so a burst that ends only switches the glitch off if
## no newer burst started in the meantime.
var _burst_id: int = 0


func _ready() -> void:
	_set_glitch(false)

	Events.set_glitch.connect(_set_glitch)
	Events.glitch_burst.connect(_burst)


func _set_glitch(glitch_state: bool) -> void:
	show() if glitch_state else hide()


## Timed in real time, so a burst fired inside a hitstop doesn't freeze on.
func _burst(duration_ms: int) -> void:
	if duration_ms <= 0:
		return
	_burst_id += 1
	var this_burst: int = _burst_id
	_set_glitch(true)
	await get_tree().create_timer(duration_ms / 1000.0, true, false, true).timeout
	if this_burst == _burst_id:
		_set_glitch(false)
