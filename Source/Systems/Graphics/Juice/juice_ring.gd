class_name JuiceRing
extends Node2D
## A one-pixel ring that grows from start_radius to end_radius while fading
## out, then frees itself. Spawned through Juice.ring().

var color: Color = Color.WHITE
var start_radius: float = 2.0
var end_radius: float = 16.0
var duration: float = 0.35

var _progress: float = 0.0:
	set(value):
		_progress = value
		queue_redraw()


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "_progress", 1.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)


func _draw() -> void:
	var radius: float = lerpf(start_radius, end_radius, _progress)
	# Squared, so the ring holds its brightness through the first half of
	# its growth and only fades once it has made its point.
	var faded: Color = Color(color, color.a * (1.0 - _progress * _progress))
	# Not antialiased: a soft edge reads as blur at this resolution.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, faded, 1.0, false)
