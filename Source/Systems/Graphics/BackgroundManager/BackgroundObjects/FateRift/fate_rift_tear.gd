extends HazardTelegraph
## A tear in space that throbs like something breathing on the other side.
## It quickens once the rift is about to open, and blazes when it does.

## Seconds per throb at rest, and while the rift is about to open.
@export var calm_period: float = 2.4
@export var urgent_period: float = 0.55

var _time: float = 0.0
var _flash: float = 0.0
var _flash_tween: Tween

@onready var _tear: Sprite2D = $Tear


func _process(delta: float) -> void:
	_time += delta
	var period: float = urgent_period if urgent else calm_period
	var wave: float = 0.5 + 0.5 * sin(TAU * _time / period)
	var low: float = 0.85 if urgent else 0.6
	var high: float = 1.7 if urgent else 1.05
	var glow: float = lerpf(low, high, wave * wave) + _flash
	_tear.self_modulate = Color(glow, glow, glow)


## Brightens toward the strike, so the tear's own flash lands on a rift
## already straining.
func _winding_up(seconds: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 1.0, seconds) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _fired() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = 2.2
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, 1.0) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
