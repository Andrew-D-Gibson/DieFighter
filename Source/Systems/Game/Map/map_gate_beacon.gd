class_name MapGateBeacon
extends Node2D
## A white light just past the map's right edge, beyond the sector's jump
## gate, with motes streaming past the gate into it. The map has a Black Hole
## at its left end; this is its answer at the right: the way on is always to
## the right. Once the gate is open the light swells and the stream thickens.
##
## Drawn by hand, a whole pixel at a time, so it sits with the map's pixel art.

## Approved palette: the highlight white and the hologram cyan.
const _LIGHT: Color = Color("#CEF0F1")
const _HALO: Color = Color("#8DF1F4")

## Where motes appear, relative to the light: a band reaching back past the
## gate, as tall as the map.
const _SPAWN_MIN: Vector2 = Vector2(-130.0, -24.0)
const _SPAWN_MAX: Vector2 = Vector2(-24.0, 18.0)
const _MOTES: int = 20
const _OPEN_MOTES: int = 32
## Pixels per second a mote starts at, and how fast it picks up speed.
const _START_SPEED: float = 8.0
const _ACCEL: float = 26.0
const _OPEN_ACCEL: float = 44.0
## Within this many pixels of the light a mote is swallowed and respawns.
const _SWALLOW_RADIUS: float = 3.0
## Halo rings, outermost first: radius, and how strongly it shows.
const _HALO_RINGS: Array[Vector2] = [
	Vector2(24.0, 0.08), Vector2(18.0, 0.14), Vector2(13.0, 0.22),
	Vector2(9.0, 0.38), Vector2(5.0, 0.7),
]
## A lens streak reaching left from the light, along the timeline, this many
## times the halo's reach.
const _STREAK_REACH: float = 2.2
const _PULSE_PERIOD: float = 1.6

var _positions: PackedVector2Array = PackedVector2Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0


func _ready() -> void:
	for i: int in range(_OPEN_MOTES):
		_positions.append(Vector2.ZERO)
		_speeds.append(0.0)
		_ages.append(0.0)
		_respawn(i)
		# Start them spread along their paths, so the stream is already
		# flowing the first time the map is opened.
		_advance(i, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, 3.0))


func _process(delta: float) -> void:
	_time += delta
	for i: int in range(_active_motes()):
		_advance(i, delta)
	queue_redraw()


func _draw() -> void:
	var swell: float = 1.0 + 0.12 * sin(_time * TAU / _PULSE_PERIOD)
	if _gate_open():
		swell *= 1.3
	for ring: Vector2 in _HALO_RINGS:
		draw_circle(Vector2.ZERO, roundf(ring.x * swell), Color(_HALO, ring.y), true, -1.0, false)
	draw_circle(Vector2.ZERO, roundf(3.0 * swell), _LIGHT, true, -1.0, false)
	var streak: float = roundf(_HALO_RINGS[0].x * _STREAK_REACH * swell)
	draw_line(Vector2(-streak, 0.0), Vector2.ZERO, Color(_LIGHT, 0.25), 1.0, false)
	draw_line(Vector2(-streak * 0.5, 0.0), Vector2.ZERO, Color(_LIGHT, 0.35), 1.0, false)

	for i: int in range(_active_motes()):
		var at: Vector2 = _positions[i]
		var to_light: Vector2 = -at.normalized()
		# Faint where it appears, bright as it nears the light.
		var near: float = clampf(1.0 - at.length() / -_SPAWN_MIN.x, 0.0, 1.0)
		var alpha: float = clampf(_ages[i] / 0.4, 0.0, 1.0) * (0.5 + 0.5 * near)
		var pixel: Vector2 = at.round()
		draw_rect(Rect2(pixel, Vector2.ONE), Color(_LIGHT, alpha))
		# A tail that stretches with speed sells the pull.
		var tail: Vector2 = (at - to_light * clampf(_speeds[i] * 0.06, 1.0, 4.0)).round()
		draw_line(tail, pixel, Color(_HALO, alpha * 0.5), 1.0, false)


func _advance(i: int, delta: float) -> void:
	var accel: float = _OPEN_ACCEL if _gate_open() else _ACCEL
	_speeds[i] += accel * delta
	_ages[i] += delta
	var at: Vector2 = _positions[i]
	var step: float = _speeds[i] * delta
	if at.length() <= _SWALLOW_RADIUS + step:
		_respawn(i)
		return
	_positions[i] = at - at.normalized() * step


func _respawn(i: int) -> void:
	_positions[i] = Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, _SPAWN_MIN.x, _SPAWN_MAX.x),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, _SPAWN_MIN.y, _SPAWN_MAX.y)
	)
	_speeds[i] = _START_SPEED
	_ages[i] = 0.0


func _active_motes() -> int:
	return _OPEN_MOTES if _gate_open() else _MOTES


func _gate_open() -> bool:
	return Globals.jump_gate != null and Globals.jump_gate.is_open()
