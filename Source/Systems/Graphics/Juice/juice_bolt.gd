class_name JuiceBolt
extends Node2D
## A jagged lightning bolt between two global points. It re-rolls its kinks
## every few frames so it crackles rather than sits, and fades as it dies.
## Spawned through Juice.zap().

const _SEGMENT_PIXELS: float = 6.0
const _JITTER_PIXELS: float = 3.0
const _RECRACKLE_SECONDS: float = 0.035

var from: Vector2
var to: Vector2
var color: Color = Color.WHITE
var duration: float = 0.14

var _age: float = 0.0
var _since_crackle: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_crackle()


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_since_crackle += delta
	if _since_crackle >= _RECRACKLE_SECONDS:
		_since_crackle = 0.0
		_crackle()
	queue_redraw()


func _crackle() -> void:
	_points.clear()
	var length: float = from.distance_to(to)
	var segments: int = maxi(2, int(length / _SEGMENT_PIXELS))
	var normal: Vector2 = (to - from).orthogonal().normalized()
	for i: int in range(segments + 1):
		var t: float = float(i) / segments
		var point: Vector2 = from.lerp(to, t)
		# Pinned at both ends, wildest in the middle.
		if i > 0 and i < segments:
			var sway: float = sin(t * PI) * _JITTER_PIXELS
			point += normal * RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -sway, sway)
		_points.append(to_local(point))


func _draw() -> void:
	if _points.size() < 2:
		return
	var life: float = 1.0 - _age / duration
	# A coloured halo under a pale core reads as hot at one pixel wide.
	draw_polyline(_points, Color(color, life), 3.0, false)
	draw_polyline(_points, Color(Color.WHITE, life), 1.0, false)
