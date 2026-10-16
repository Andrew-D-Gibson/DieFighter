extends Camera2D

## How far toward a zoom punch's focus the camera leans at the peak, as a
## fraction of the distance. Small: enough to feel directional, not a pan.
const _PUNCH_FOCUS_LEAN: float = 0.08
const _PUNCH_IN_SECONDS: float = 0.05
const _PUNCH_OUT_SECONDS: float = 0.3

## The kill cam snaps most of the way in at once, then creeps the rest of the
## way through the hold, so the held frame never sits dead still.
const _KILL_CAM_SNAP_ZOOM: float = 1.3
const _KILL_CAM_PEAK_ZOOM: float = 1.4
const _KILL_CAM_SNAP_SECONDS: float = 0.06
const _KILL_CAM_OUT_SECONDS: float = 0.45
## Leans much harder than a punch: the dying ship should end up near the middle
## of the frame, the way a fighting game frames its finishing blow.
const _KILL_CAM_FOCUS_LEAN: float = 0.6

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
	Events.camera_kill_cam.connect(_kill_cam)


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


## Pushes in on a kill and holds there through its hitstop, then pulls back as
## time resumes. Shares the punch tween: a kill cam takes over from any punch
## in flight, and a punch landing during the hold would only fight it.
func _kill_cam(focus: Vector2, hold_seconds: float) -> void:
	if not Globals.screenshake_enabled:
		return

	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	var lean: Vector2 = (focus - get_screen_center_position() + offset) * _KILL_CAM_FOCUS_LEAN
	var creep_seconds: float = maxf(hold_seconds - _KILL_CAM_SNAP_SECONDS, 0.0)

	# Real time throughout: the hold is a hitstop, where game time stands still.
	_punch_tween = create_tween().set_ignore_time_scale(true)
	_punch_tween.tween_property(self, "zoom", _resting_zoom * _KILL_CAM_SNAP_ZOOM, _KILL_CAM_SNAP_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.parallel().tween_property(self, "offset", lean, _KILL_CAM_SNAP_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "zoom", _resting_zoom * _KILL_CAM_PEAK_ZOOM, creep_seconds)
	_punch_tween.tween_property(self, "zoom", _resting_zoom, _KILL_CAM_OUT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.parallel().tween_property(self, "offset", Vector2.ZERO, _KILL_CAM_OUT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
