extends Node2D
## What's left of "You" once the player's die has broken it
## (RECKONING_ENDINGS.md §4, §6.5): no wreck, no fire, only the glitch slices
## that pulled it apart, drifting away from each other, stuttering and
## going out. Drawn in whole art pixels round this node's origin.

## Seconds the slices take to go out.
@export var lifetime: float = 5.0
@export var num_of_slices: int = 22

## Approved palette: Fate's purples, the outline navy and a white for the
## brightest glints.
const _COLORS: Array[Color] = [
	Color("#c552f1"), Color("#a846ce"), Color("#80359d"),
	Color("#463c91"), Color("#040217"), Color("#cef0f1"),
]

## Per slice: where it is, how fast it drifts, its size and colour.
var _at: PackedVector2Array = PackedVector2Array()
var _drift: PackedVector2Array = PackedVector2Array()
var _size: PackedVector2Array = PackedVector2Array()
var _color: PackedColorArray = PackedColorArray()
## When each slice goes out, as a share of the lifetime.
var _out_at: PackedFloat32Array = PackedFloat32Array()
var _age: float = 0.0


func _ready() -> void:
	for i: int in num_of_slices:
		# Mostly long and thin, cut across: the slices of a scanline glitch.
		_size.append(Vector2(roundf(_randf(3.0, 16.0)), roundf(_randf(1.0, 2.4))))
		_at.append(Vector2(_randf(-12.0, 12.0), _randf(-11.0, 11.0)))
		# They come apart sideways more than up and down.
		_drift.append(Vector2(_randf(-9.0, 9.0), _randf(-2.5, 2.5)))
		_color.append(_COLORS[int(_randf(0.0, _COLORS.size() - 0.01))])
		_out_at.append(_randf(0.25, 1.0))


func _process(delta: float) -> void:
	_age += delta
	for i: int in _at.size():
		_at[i] += _drift[i] * delta
	queue_redraw()
	if _age > lifetime:
		queue_free()


func _draw() -> void:
	var life: float = _age / lifetime
	for i: int in _at.size():
		if life > _out_at[i]:
			continue
		# Stutters more the nearer it is to going out.
		var stutter: float = remap(life, 0.0, _out_at[i], 0.05, 0.6)
		if _randf(0.0, 1.0) < stutter:
			continue
		var at: Vector2 = _at[i].floor()
		draw_rect(Rect2(at - Vector2(floorf(_size[i].x / 2.0), 0.0), _size[i].floor()), _color[i])


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
