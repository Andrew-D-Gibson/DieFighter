class_name ArrivalFlare
extends Node2D
## A signal flare (RECKONING_ENDINGS.md §6.3-6.4): a pixel streak climbing up
## and out of a ship, slowing, then bursting into a few sparks. Drawn a pixel
## at a time on the 320x180 grid. Frees itself once the sparks are out.
##
## The Convoy fires them for joy; the Last Die fires the same flares in the
## drive's gold, slowed down: joy and mourning share one vocabulary, so only
## [member pace] and the colour tell them apart.

## The flare's own colour: the firing ship's faction, or the drive's gold.
var color: Color = Color.WHITE
## How high it climbs before it bursts, in art pixels.
var height: float = 36.0
## Which way it climbs, in radians off straight up; positive leans right.
var lean: float = 0.0
## 1 is a festive flare; under 1, everything happens that much slower.
var pace: float = 1.0
var spark_count: int = 8

const _CLIMB_SECONDS: float = 0.8
const _BURST_SECONDS: float = 1.1
## How far back along the climb the streak behind the head reaches.
const _TRAIL_SECONDS: float = 0.22

var _age: float = 0.0
var _sparks: Array[Vector2] = []
var _spark_velocities: Array[Vector2] = []
## Where each spark was a moment ago: a pixel of tail, so it reads as moving.
var _spark_tails: Array[Vector2] = []
var _burst_at: Vector2 = Vector2.ZERO
var _burst: bool = false


func _process(delta: float) -> void:
	_age += delta * pace
	if not _burst and _age >= _CLIMB_SECONDS:
		_start_burst()
	if _burst:
		for i: int in _sparks.size():
			# Hard drag: a burst opens fast and hangs, as a flare's sparks do.
			_spark_velocities[i] *= exp(-2.4 * delta * pace)
			_spark_velocities[i].y += 10.0 * delta * pace
			_spark_tails[i] = _sparks[i]
			_sparks[i] += _spark_velocities[i] * delta * pace
		if _age >= _CLIMB_SECONDS + _BURST_SECONDS:
			queue_free()
	queue_redraw()


func _draw() -> void:
	if not _burst:
		var head: Vector2 = _climb_point(_age)
		var tail: Vector2 = _climb_point(maxf(_age - _TRAIL_SECONDS, 0.0))
		var steps: int = maxi(1, ceili(head.distance_to(tail)))
		for i: int in range(steps + 1):
			var t: float = float(i) / steps
			var shade: Color = Color(color, lerpf(0.15, 1.0, t))
			_pixel(tail.lerp(head, t), shade)
		# A white-hot head, so the streak reads as burning, not painted.
		_pixel(head, Color.WHITE.lerp(color, 0.25))
		return
	var life: float = clampf((_age - _CLIMB_SECONDS) / _BURST_SECONDS, 0.0, 1.0)
	# The first instant of the burst is a flash at its heart.
	if life < 0.15:
		for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_pixel(_burst_at + offset, Color.WHITE.lerp(color, 0.4))
	for i: int in _sparks.size():
		# Squared, so the sparks hold their colour and only go at the end.
		var fade: float = 1.0 - life * life
		_pixel(_spark_tails[i], Color(color, fade * 0.45))
		_pixel(_sparks[i], Color(color, fade))


## Where the head is [param age] seconds into the climb: fast off the ship,
## easing to a stop at the top.
func _climb_point(age: float) -> Vector2:
	var t: float = clampf(age / _CLIMB_SECONDS, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 2.2)
	return Vector2.UP.rotated(lean) * height * eased


func _start_burst() -> void:
	_burst = true
	_burst_at = _climb_point(_CLIMB_SECONDS)
	for i: int in spark_count:
		# Spread round evenly, then jittered, so a burst never clumps on one side.
		var angle: float = TAU * i / spark_count + _randf(-0.4, 0.4)
		_sparks.append(_burst_at)
		_spark_tails.append(_burst_at)
		_spark_velocities.append(Vector2.from_angle(angle) * _randf(28.0, 42.0))


func _pixel(at: Vector2, shade: Color) -> void:
	draw_rect(Rect2(at.round(), Vector2.ONE), shade)


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
