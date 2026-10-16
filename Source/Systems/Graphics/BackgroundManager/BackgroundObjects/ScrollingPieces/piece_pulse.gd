class_name PiecePulse
extends CanvasItem
## Throbs a scrolling piece's glow, brightness only: a cracked die's fissure,
## a cinder's cracks. Each copy starts at a random point in the throb.

@export var period: float = 2.0
@export var low: float = 0.7
@export var high: float = 1.4

var _phase: float = 0.0


func _ready() -> void:
	_phase = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)


func _process(delta: float) -> void:
	_phase = fmod(_phase + TAU * delta / period, TAU)
	var glow: float = lerpf(low, high, 0.5 + 0.5 * sin(_phase))
	self_modulate = Color(glow, glow, glow, self_modulate.a)
