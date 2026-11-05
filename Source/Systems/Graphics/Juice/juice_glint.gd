class_name JuiceGlint
extends Node2D
## A four-point star that flares out from a point and shrinks away, then
## frees itself: light catching an edge. Spawned through Juice.glint().

var color: Color = Color.WHITE
## How far each point reaches at the peak, in pixels.
var reach: float = 5.0
var duration: float = 0.35

var _progress: float = 0.0:
	set(value):
		_progress = value
		queue_redraw()


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "_progress", 1.0, duration)
	tween.finished.connect(queue_free)


func _draw() -> void:
	# Up fast, down slow: a flare, not a pulse.
	var size: float = sin(pow(_progress, 0.6) * PI) * reach
	if size < 0.5:
		return
	# Not antialiased: a soft edge reads as blur at this resolution.
	draw_line(Vector2(-size, 0.0), Vector2(size, 0.0), color, 1.0, false)
	draw_line(Vector2(0.0, -size), Vector2(0.0, size), color, 1.0, false)
	# A brighter core so the star has a centre.
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color.WHITE.lerp(color, 0.3))
