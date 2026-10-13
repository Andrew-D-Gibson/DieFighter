extends HazardTelegraph
## The star a solar flare region sits beside, and the source of its flares.
##
## Breathes slowly while the flare is far off. Once it is imminent the corona
## flares hot and throbs fast, so the sky itself is shouting "next turn"; when
## it fires, the whole star whites out.
##
## Brightness only, never scale or rotation: either would smear the pixel art.

## Seconds per breath at rest, and while the flare is imminent.
@export var calm_period: float = 3.2
@export var urgent_period: float = 0.7

## How hot the corona runs at the peak of a breath, calm and imminent.
@export var calm_glow: float = 1.1
@export var urgent_glow: float = 1.9

@onready var _body: Sprite2D = $Body
@onready var _corona: Sprite2D = $Corona

var _time: float = 0.0

## Extra brightness from a flare, decaying back to zero.
var _flash: float = 0.0
var _flash_tween: Tween


func _process(delta: float) -> void:
	_time += delta
	var period: float = urgent_period if urgent else calm_period
	var wave: float = 0.5 + 0.5 * sin(TAU * _time / period)
	var peak: float = urgent_glow if urgent else calm_glow

	var corona: float = lerpf(0.85, peak, wave) + _flash
	_corona.self_modulate = Color(corona, corona, corona, lerpf(0.7, 1.0, wave))
	var body: float = 1.0 + (0.15 * wave if urgent else 0.0) + _flash * 0.6
	_body.self_modulate = Color(body, body, body)


func _fired() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = 2.5
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, 1.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
