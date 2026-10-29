extends Camera2D

## How far toward a zoom punch's focus the camera leans at the peak, as a
## fraction of the distance. Small: enough to feel directional, not a pan.
const _PUNCH_FOCUS_LEAN: float = 0.08
const _PUNCH_IN_SECONDS: float = 0.05
const _PUNCH_OUT_SECONDS: float = 0.3

## The kill cam snaps most of the way in at once, then creeps the rest of the
## way through the hold, so the held frame never sits dead still. Kept gentle
## (it was 1.3 to 1.4): a kill comes several times a fight, and a deep push-in
## each time read as jarring rather than punchy. At full Screenshake; the
## setting scales it down from there, to nothing at 0.
const _KILL_CAM_SNAP_ZOOM: float = 1.12
const _KILL_CAM_PEAK_ZOOM: float = 1.16
const _KILL_CAM_SNAP_SECONDS: float = 0.06
const _KILL_CAM_OUT_SECONDS: float = 0.45
## Leans harder than a punch, toward the dying ship, the way a fighting game
## frames its finishing blow. Eased off with the zoom (it was 0.6): a big lean
## at a small zoom reads as the camera lurching sideways.
const _KILL_CAM_FOCUS_LEAN: float = 0.3

## Zoom the camera rests at. Punches are relative to it, so an overlapping
## punch can't ratchet the camera further in each time.
var _resting_zoom: Vector2
var _punch_tween: Tween


func _ready() -> void:
	_resting_zoom = zoom

	# Every camera move here scales with the screenshake setting; at zero
	# there's none at all.
	Events.camera_shake_small.connect(func() -> void:
		if Globals.screenshake_enabled:
			$Shakeable.small_shake(Globals.screenshake_intensity)
	)
	Events.camera_shake_large.connect(func(glitch: bool = false) -> void:
		if Globals.screenshake_enabled:
			$Shakeable.large_shake(Globals.screenshake_intensity)

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
	# A punch is camera motion, so it shrinks with the screenshake setting.
	peak_zoom = scaled_zoom(peak_zoom, Globals.screenshake_intensity)
	if peak_zoom <= 1.0:
		return

	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	var lean: Vector2 = Vector2.ZERO
	if has_focus:
		lean = (focus - get_screen_center_position()) * _PUNCH_FOCUS_LEAN * Globals.screenshake_intensity

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

	var intensity: float = Globals.screenshake_intensity
	var lean: Vector2 = (focus - get_screen_center_position() + offset) * _KILL_CAM_FOCUS_LEAN * intensity
	var creep_seconds: float = maxf(hold_seconds - _KILL_CAM_SNAP_SECONDS, 0.0)

	# Effect time throughout: the hold is a hitstop, where game time stands still.
	_punch_tween = TimeDirector.effect_tween(self)
	_punch_tween.tween_property(self, "zoom", _resting_zoom * scaled_zoom(_KILL_CAM_SNAP_ZOOM, intensity), _KILL_CAM_SNAP_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.parallel().tween_property(self, "offset", lean, _KILL_CAM_SNAP_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "zoom", _resting_zoom * scaled_zoom(_KILL_CAM_PEAK_ZOOM, intensity), creep_seconds)
	_punch_tween.tween_property(self, "zoom", _resting_zoom, _KILL_CAM_OUT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_punch_tween.parallel().tween_property(self, "offset", Vector2.ZERO, _KILL_CAM_OUT_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## A zoom of [param zoom] times the resting one, pulled back toward no zoom
## at all as [param intensity] drops from 1 to 0.
static func scaled_zoom(zoom: float, intensity: float) -> float:
	return 1.0 + (zoom - 1.0) * clampf(intensity, 0.0, 1.0)
