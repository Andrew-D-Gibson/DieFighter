extends ColorRect

@export var vignette_flash_time: float = 0.75
@export var vignette_alpha: float = 0.35

## A shield break lingers and burns brighter than a chip hit — it's the
## transition from protected to exposed, and it should read as one.
@export var break_flash_time: float = 1.4
@export var break_alpha: float = 0.6

## How long one red-alert pulse takes to swell and fade. Slower than a damage
## flash: an alarm is a condition, not an impact.
@export var alert_pulse_time: float = 0.55
@export var alert_alpha: float = 0.55

## Under Reduce Flashing every pulse rises this many times slower, so the
## edges swell rather than flash.
const _REDUCED_RISE_FACTOR: float = 4.0

## Critical hull: the edges beat red, lub-dub, for as long as it lasts. Peaks
## of each beat, and the seconds the whole beat takes (a racing pulse).
@export var heartbeat_alpha: float = 0.5
@export var heartbeat_period: float = 0.85

## Kept so a new red alert can cut off one already running rather than fighting
## it for the same shader parameter.
var _alert_tween: Tween

## The heartbeat runs on a layer of its own under every flash: it's a
## condition that lasts for turns, and the hits still have to read over it.
var _heartbeat: ColorRect
var _heartbeat_tween: Tween


func _ready() -> void:
	visible = true
	_heartbeat = ColorRect.new()
	_heartbeat.material = material.duplicate()
	_heartbeat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_heartbeat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heartbeat.show_behind_parent = true
	_heartbeat.material.set_shader_parameter('color', Globals.red)
	_heartbeat.material.set_shader_parameter('alpha', 0.0)
	add_child(_heartbeat)
	Events.player_hull_critical_changed.connect(_set_heartbeat)
	Events.player_health_hit.connect(_pulse_vignette.bind(Globals.red))
	Events.player_shields_hit.connect(_pulse_vignette.bind(Globals.blue))
	Events.player_shields_broken.connect(_shield_break_vignette)
	Events.red_alert.connect(_red_alert_vignette)
	Events.vignette_pulse.connect(_pulse_vignette)
	Events.hazard_winding_up.connect(_hazard_wind_up)
	Events.hazard_struck.connect(_hazard_strike)


## Cyan rather than blue, brighter, and slow to fade: the hull is bare now.
func _shield_break_vignette() -> void:
	material.set_shader_parameter('color', Color.html('#8df1f4'))

	_swell(break_alpha, break_flash_time * 0.06, break_flash_time * 0.94)


## A hazard building to its strike: the edges swell in its colour in pulses
## that come faster and burn brighter toward the hit, like an alarm winding up.
func _hazard_wind_up(hazard: BackgroundHazardResource, seconds: float) -> void:
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	material.set_shader_parameter('color', hazard.color)
	_alert_tween = get_tree().create_tween()
	if Globals.reduce_flashing:
		# One steady swell instead of quickening pulses.
		_alert_tween.tween_property(self, "material:shader_parameter/alpha", _soft(alert_alpha), seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	# Fractions of the wind-up each pulse takes: long, shorter, shortest.
	var pulses: Array[float] = [0.45, 0.3, 0.25]
	for i: int in range(pulses.size()):
		var peak: float = lerpf(alert_alpha * 0.5, alert_alpha * 1.2, float(i) / (pulses.size() - 1))
		_alert_tween.tween_property(
			self, "material:shader_parameter/alpha", peak, seconds * pulses[i] * 0.6
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_alert_tween.tween_property(
			self, "material:shader_parameter/alpha", peak * 0.35, seconds * pulses[i] * 0.4
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The strike: the hazard's colour floods the edges, then drains slowly.
func _hazard_strike(hazard: BackgroundHazardResource) -> void:
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	material.set_shader_parameter('color', hazard.color)
	_alert_tween = get_tree().create_tween()
	_alert_tween.tween_property(self, "material:shader_parameter/alpha", _soft(0.85), _rise(0.05))
	_alert_tween.tween_property(self, "material:shader_parameter/alpha", 0.0, break_flash_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Same shape as a hit flash, in whatever color the authored effect asked for.
func _pulse_vignette(tint: Color) -> void:
	material.set_shader_parameter('color', tint)

	_swell(vignette_alpha, vignette_flash_time * 0.1, vignette_flash_time * 0.9)


## Pulses red for `duration` seconds, then settles back to clear. Used by the
## cold open: the player arrives already under fire, and the screen should say
## so before any text does.
func _red_alert_vignette(duration: float) -> void:
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()

	material.set_shader_parameter('color', Globals.red)

	_alert_tween = get_tree().create_tween()
	if Globals.reduce_flashing:
		# A steady glow for the whole alarm rather than a run of pulses.
		var rise: float = minf(alert_pulse_time, duration * 0.5)
		_alert_tween.tween_property(self, "material:shader_parameter/alpha", _soft(alert_alpha), rise) \
			.set_trans(Tween.TRANS_SINE)
		_alert_tween.tween_property(self, "material:shader_parameter/alpha", 0.0, rise) \
			.set_trans(Tween.TRANS_SINE).set_delay(maxf(duration - rise * 2.0, 0.0))
		return

	var pulses: int = maxi(1, int(round(duration / alert_pulse_time)))

	for i: int in range(pulses):
		# The last pulse fades to nothing; the ones before it stay slightly lit
		# so the alarm reads as continuous rather than as separate flashes.
		var trough: float = 0.0 if i == pulses - 1 else alert_alpha * 0.35
		_alert_tween.tween_property(
			self, "material:shader_parameter/alpha", alert_alpha, alert_pulse_time * 0.35
		).set_trans(Tween.TRANS_QUAD)
		_alert_tween.tween_property(
			self, "material:shader_parameter/alpha", trough, alert_pulse_time * 0.65
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Starts or stops the critical-hull heartbeat. Under Reduce Flashing it
## breathes slowly instead of beating.
func _set_heartbeat(critical: bool) -> void:
	if _heartbeat_tween and _heartbeat_tween.is_valid():
		_heartbeat_tween.kill()
	_heartbeat_tween = _heartbeat.create_tween()
	if not critical:
		_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", 0.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return

	_heartbeat_tween.set_loops()
	var beat: float = heartbeat_period
	if Globals.reduce_flashing:
		var breath: float = beat * _REDUCED_RISE_FACTOR * 0.5
		_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", _soft(heartbeat_alpha), breath) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", _soft(heartbeat_alpha) * 0.3, breath) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	# Lub: the strong beat. Dub: a softer echo close behind. Then a rest,
	# never quite dark, so the danger reads as continuous.
	var floor_alpha: float = heartbeat_alpha * 0.15
	_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", heartbeat_alpha, beat * 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", heartbeat_alpha * 0.3, beat * 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", heartbeat_alpha * 0.7, beat * 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_heartbeat_tween.tween_property(_heartbeat, "material:shader_parameter/alpha", floor_alpha, beat * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Rises from nothing to [param peak] in [param rise] seconds and fades back
## over [param fade]. Under Reduce Flashing, dimmer and slower to rise.
func _swell(peak: float, rise: float, fade: float) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", _soft(peak), _rise(rise)).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _soft(alpha: float) -> float:
	return Juice.soften_flash(alpha)


func _rise(seconds: float) -> float:
	return seconds * _REDUCED_RISE_FACTOR if Globals.reduce_flashing else seconds
