class_name LightningBolt
extends RefCounted
## The shape of one pixel-art lightning bolt: a jagged, one-pixel-wide core
## that may fork, and the ring of pixels glowing around it. Shared by the
## background storms (Fate's weather, the ion storm), which decide when a bolt
## strikes, how long it lights the sky and what colour it burns.
##
## Coordinates are art pixels in whatever space the caller draws in. Random
## draws come from the COSMETIC bucket: a bolt's shape never touches the game.

## A bolt steps this many art pixels between kinks.
const STEP: Vector2 = Vector2(3.0, 7.0)
## How far each kink may swing off the bolt's heading, in radians.
const KINK: float = 0.6
## The odds, per kink, that a fork splits off while any are left.
const FORK_CHANCE: float = 0.25

## The lit pixels, and the pixels glowing around them.
var core: Array[Vector2i] = []
var glow: Array[Vector2i] = []


## Walks a jagged line from [param start] heading roughly [param angle] for
## [param length] art pixels, forking off up to [param forks] shorter
## branches.
static func grow(start: Vector2, angle: float, length: float, forks: int) -> LightningBolt:
	var bolt: LightningBolt = LightningBolt.new()
	var lit: Dictionary[Vector2i, bool] = {}
	_walk(lit, start, angle, length, forks)
	for pixel: Vector2i in lit:
		bolt.core.append(pixel)
	var halo: Dictionary[Vector2i, bool] = {}
	for pixel: Vector2i in lit:
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbour: Vector2i = pixel + offset
			if not lit.has(neighbour):
				halo[neighbour] = true
	for pixel: Vector2i in halo:
		bolt.glow.append(pixel)
	return bolt


## Draws the bolt onto [param canvas] (from inside its _draw()): the glow
## first, then the core over it.
func draw_on(canvas: CanvasItem, core_color: Color, glow_color: Color) -> void:
	for pixel: Vector2i in glow:
		canvas.draw_rect(Rect2(pixel, Vector2.ONE), glow_color)
	for pixel: Vector2i in core:
		canvas.draw_rect(Rect2(pixel, Vector2.ONE), core_color)


static func _walk(lit: Dictionary[Vector2i, bool], from: Vector2, angle: float, length: float, forks: int) -> void:
	var position_now: Vector2 = from
	var travelled: float = 0.0
	while travelled < length:
		var step_length: float = _randf(STEP.x, STEP.y)
		var heading: float = angle + _randf(-KINK, KINK)
		var next: Vector2 = position_now + Vector2.from_angle(heading) * step_length
		_line(lit, Vector2i(position_now.round()), Vector2i(next.round()))
		position_now = next
		travelled += step_length
		if forks > 0 and _randf(0.0, 1.0) < FORK_CHANCE:
			forks -= 1
			var side: float = 1.0 if _randf(0.0, 1.0) < 0.5 else -1.0
			_walk(lit, position_now, angle + side * _randf(0.4, 0.9), (length - travelled) * 0.5, 0)


## Bresenham, so a bolt is one clean pixel wide however it bends.
static func _line(lit: Dictionary[Vector2i, bool], a: Vector2i, b: Vector2i) -> void:
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var error: int = dx + dy
	var point: Vector2i = a
	while true:
		lit[point] = true
		if point == b:
			return
		var doubled: int = 2 * error
		if doubled >= dy:
			error += dy
			point.x += sx
		if doubled <= dx:
			error += dx
			point.y += sy


static func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
