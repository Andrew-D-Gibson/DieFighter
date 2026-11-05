class_name HorizonVoidCell
extends Node2D
## A grid cell the Reckoning's event horizon has eaten: black, with Fate's
## purple crawling round its rim and a few motes falling inward. Drawn rather
## than painted so it fits any ship's cell size.

## Approved palette: void, Fate purple ramp.
const _VOID: Color = Color("#000000")
const _RIM: Color = Color("#c552f1")
const _RIM_DARK: Color = Color("#80359d")
const _MOTE: Color = Color("#a846ce")

var size: Vector2 = Vector2(24, 24)
var _age: float = 0.0


func _ready() -> void:
	# Grows in from the centre as the column goes.
	scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var inset: Rect2 = Rect2(Vector2(1, 1), size - Vector2(2, 2))
	draw_rect(inset, _VOID)
	# The rim crawls: each edge pixel lit or dark by a slow travelling wave.
	var w: int = int(inset.size.x)
	var h: int = int(inset.size.y)
	var perimeter: int = 2 * (w + h)
	for i: int in perimeter:
		var lit: bool = sin(i * 0.9 - _age * 5.0) > 0.2
		draw_rect(Rect2(_perimeter_point(i, w, h) + inset.position, Vector2.ONE), _RIM if lit else _RIM_DARK)
	# Motes spiral in toward the middle, fixed in number so it costs no RNG.
	var centre: Vector2 = size / 2.0
	for i: int in 4:
		var t: float = fmod(_age * 0.6 + i * 0.25, 1.0)
		var angle: float = i * TAU / 4.0 + t * 3.0
		var radius: float = (1.0 - t) * (minf(w, h) / 2.0 - 1.0)
		var point: Vector2 = (centre + Vector2.from_angle(angle) * radius).floor()
		draw_rect(Rect2(point, Vector2.ONE), Color(_MOTE, 1.0 - t))


func _perimeter_point(i: int, w: int, h: int) -> Vector2:
	if i < w:
		return Vector2(i, 0)
	i -= w
	if i < h:
		return Vector2(w - 1, i)
	i -= h
	if i < w:
		return Vector2(w - 1 - i, h - 1)
	i -= w
	return Vector2(0, h - 1 - i)
