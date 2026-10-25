extends HazardTelegraph
## The star a solar flare region sits beside, and the source of its flares.
##
## Breathes slowly while the flare is far off. Once it is imminent its limb
## erupts in prominences and the whole star throbs fast and hot, so the sky
## itself is shouting "next turn"; when it fires, the star whites out.
##
## The star is drawn live by pixel_planet.gdshader on Body; this only drives
## its brightness and how much of its limb is erupting. Never touch the
## shader's speeds from here: they multiply TIME, so changing one jumps the
## surface to a new place instead of speeding it up.

## Seconds per breath at rest, and while the flare is imminent.
@export var calm_period: float = 3.2
@export var urgent_period: float = 0.7

## How hot the star runs at the peak of a breath, calm and imminent.
@export var calm_glow: float = 1.1
@export var urgent_glow: float = 1.7

## How much of the limb is erupting (the shader's cloud cover), calm and
## imminent, and how long it takes to climb or settle between them.
@export var calm_prominences: float = 0.3
@export var urgent_prominences: float = 0.45
@export var prominence_shift_time: float = 1.5

@onready var _body: ColorRect = $Body
@onready var _material: ShaderMaterial = _body.material as ShaderMaterial

## Where in its breath the star is, in radians. Advanced by the current
## period, so switching to the urgent throb doesn't jump the glow.
var _phase: float = 0.0

## Extra brightness from a flare, decaying back to zero.
var _flash: float = 0.0
var _flash_tween: Tween

var _prominences: float = 0.0
var _prominence_tween: Tween


func _ready() -> void:
	super()
	_prominences = calm_prominences


func _process(delta: float) -> void:
	var period: float = urgent_period if urgent else calm_period
	_phase = fmod(_phase + TAU * delta / period, TAU)
	var wave: float = 0.5 + 0.5 * sin(_phase)
	var peak: float = urgent_glow if urgent else calm_glow

	var glow: float = lerpf(0.9, peak, wave) + _flash
	_body.self_modulate = Color(glow, glow, glow)
	_material.set_shader_parameter("cloud_1_cover", _prominences)


func _urgency_changed() -> void:
	if _prominence_tween and _prominence_tween.is_valid():
		_prominence_tween.kill()
	_prominence_tween = create_tween()
	_prominence_tween.tween_property(
		self, "_prominences", urgent_prominences if urgent else calm_prominences,
		prominence_shift_time
	).set_trans(Tween.TRANS_SINE)


## Brightens toward the strike, so the flare's own flash lands on a star
## already burning hot.
func _winding_up(seconds: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 1.0, seconds) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _fired() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = 2.5
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, 1.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
