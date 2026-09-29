extends Camera2D

## How far toward a zoom punch's focus the camera leans at the peak, as a
## fraction of the distance. Small: enough to feel directional, not a pan.
const _PUNCH_FOCUS_LEAN: float = 0.08
const _PUNCH_IN_SECONDS: float = 0.05
const _PUNCH_OUT_SECONDS: float = 0.3

## Zoom the camera rests at. Punches are relative to it, so an overlapping
## punch can't ratchet the camera further in each time.
var _resting_zoom: Vector2
var _punch_tween: Tween


func _ready() -> void:
	_resting_zoom = zoom

	Events.camera_shake_small.connect(func() -> void:
		if Globals.screenshake_enabled:
			$Shakeable.small_shake()
	)
	Events.camera_shake_large.connect(func(glitch: bool = false) -> void:
		if Globals.screenshake_enabled:
			$Shakeable.large_shake()

			if glitch:
				Events.set_glitch.emit(true)
				await $Shakeable.shake_ended
				Events.set_glitch.emit(false)

	)
	Events.camera_zoom_punch.connect(_zoom_punch)


## Snaps in fast and eases back out. The lean goes through `offset` rather than
## position, because Shakeable owns position while a shake is running.
func _zoom_punch(peak_zoom: float, focus: Vector2, has_focus: bool) -> void:
	# A punch is camera motion; players who turned shake off turned this off too.
	if not Globals.screenshake_enabled or peak_zoom <= 1.0:
		return

	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	var lean: Vector2 = Vector2.ZERO
	if has_focus:
		lean = (focus - get_screen_center_position()) * _PUNCH_FOCUS_LEAN

	_punch_tween = create_tween().set_parallel(true)
	_punch_tween.tween_property(self, "zoom", _resting_zoom * peak_zoom, _PUNCH_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "offset", lean, _PUNCH_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.chain().tween_property(self, "zoom", _resting_zoom, _PUNCH_OUT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.parallel().tween_property(self, "offset", Vector2.ZERO, _PUNCH_OUT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
