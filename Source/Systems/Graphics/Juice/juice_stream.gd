class_name JuiceStream
extends Node2D
## A handful of motes that arc from one global point to another, each a
## little behind the last and bowing out to its own side, so the transfer
## reads as a flow being pulled across. Spawned through Juice.stream().

const _FLIGHT_SECONDS: float = 0.35
const _STAGGER_SECONDS: float = 0.025
const _BOW_PIXELS: float = 14.0

var from: Vector2
var to: Vector2
var color: Color = Color.WHITE
var count: int = 10

var _age: float = 0.0
## Per mote: how far it bows off the straight line, signed.
var _bows: PackedFloat32Array = PackedFloat32Array()


func total_seconds() -> float:
	return _FLIGHT_SECONDS + _STAGGER_SECONDS * maxi(0, count - 1)


func _ready() -> void:
	for i: int in range(count):
		_bows.append(RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -_BOW_PIXELS, _BOW_PIXELS))


func _process(delta: float) -> void:
	_age += delta
	if _age >= total_seconds():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var normal: Vector2 = (to - from).orthogonal().normalized()
	for i: int in range(count):
		var t: float = (_age - i * _STAGGER_SECONDS) / _FLIGHT_SECONDS
		if t <= 0.0 or t >= 1.0:
			continue
		var eased: float = t * t * (3.0 - 2.0 * t)
		var point: Vector2 = from.lerp(to, eased) + normal * _bows[i] * sin(eased * PI)
		var local: Vector2 = to_local(point).round()
		draw_rect(Rect2(local - Vector2.ONE, Vector2(2, 2)), color)
		# A one-pixel tail behind each mote sells the speed.
		var behind: Vector2 = to_local(from.lerp(to, maxf(0.0, eased - 0.08))).round()
		draw_line(behind, local, Color(color, 0.5), 1.0, false)
