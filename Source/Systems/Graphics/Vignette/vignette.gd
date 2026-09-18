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

## Kept so a new red alert can cut off one already running rather than fighting
## it for the same shader parameter.
var _alert_tween: Tween


func _ready() -> void:
	visible = true
	Events.player_health_hit.connect(_health_hit_vignette)
	Events.player_shields_hit.connect(_shield_hit_vignette)
	Events.player_shields_broken.connect(_shield_break_vignette)
	Events.red_alert.connect(_red_alert_vignette)
	


func _health_hit_vignette() -> void:
	material.set_shader_parameter('color', Globals.red)
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", vignette_alpha, vignette_flash_time * 0.1).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, vignette_flash_time * 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	
func _shield_hit_vignette() -> void:
	material.set_shader_parameter('color', Globals.blue)
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", vignette_alpha, vignette_flash_time * 0.1).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, vignette_flash_time * 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Cyan rather than blue, brighter, and slow to fade: the hull is bare now.
func _shield_break_vignette() -> void:
	material.set_shader_parameter('color', Color.html('#8df1f4'))

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "material:shader_parameter/alpha", break_alpha, break_flash_time * 0.06).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "material:shader_parameter/alpha", 0, break_flash_time * 0.94).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Pulses red for `duration` seconds, then settles back to clear. Used by the
## cold open: the player arrives already under fire, and the screen should say
## so before any text does.
func _red_alert_vignette(duration: float) -> void:
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()

	material.set_shader_parameter('color', Globals.red)

	var pulses: int = maxi(1, int(round(duration / alert_pulse_time)))
	_alert_tween = get_tree().create_tween()

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
