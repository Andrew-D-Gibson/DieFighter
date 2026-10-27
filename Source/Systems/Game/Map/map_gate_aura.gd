class_name MapGateAura
extends Node2D
## The light around the sector's jump gate on the map, so the eye goes to it:
## a soft halo that breathes behind the icon, and motes swirling in from all
## around to be swallowed by the portal. Livelier once the gate is open.
##
## The map gives the gate's icon two of these: one behind it (the halo) and
## one in front (the motes). Children of the icon, so they grow with it when
## it's hovered. Drawn by hand, a whole pixel at a time, to sit with the map's
## pixel art.

enum Layer { HALO, MOTES }

## Approved palette: highlight white, hologram cyan, bright blue.
const _WHITE: Color = Color("#CEF0F1")
const _CYAN: Color = Color("#8DF1F4")
const _BLUE: Color = Color("#43A6FC")

## Halo rings, outermost first: radius, and how strongly it shows.
const _HALO_RINGS: Array[Vector2] = [
	Vector2(19.0, 0.05), Vector2(15.0, 0.09), Vector2(12.0, 0.14),
	Vector2(10.0, 0.2),
]
const _PULSE_SECONDS: float = 1.8
## A quick bright ring that swells out from the gate now and then.
const _BEAT_SECONDS: float = 2.4

const _MOTES: int = 12
const _OPEN_MOTES: int = 22
## Where motes appear (radius from the gate's centre), and where they're
## swallowed (the portal's edge).
const _SPAWN_RADIUS: Vector2 = Vector2(16.0, 28.0)
const _SWALLOW_RADIUS: float = 3.0
## Inward speed: start, and pick-up per second. Faster when open.
const _START_SPEED: float = 5.0
const _ACCEL: float = 16.0
const _OPEN_ACCEL: float = 28.0
## Radians per second a mote circles at the spawn radius. It circles faster
## as it nears the portal, so the stream reads as a whirlpool.
const _SWIRL: float = 1.1
## Longest a mote's tail gets, in pixels.
const _MAX_TAIL: float = 3.0

var layer: Layer = Layer.HALO

var _time: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _ages: PackedFloat32Array = PackedFloat32Array()


static func make(of_layer: Layer) -> MapGateAura:
	var aura: MapGateAura = MapGateAura.new()
	aura.layer = of_layer
	# The halo lights the space behind the icon, never over it.
	aura.show_behind_parent = of_layer == Layer.HALO
	return aura


func _ready() -> void:
	if layer != Layer.MOTES:
		return
	for i: int in range(_OPEN_MOTES):
		_angles.append(0.0)
		_radii.append(0.0)
		_speeds.append(0.0)
		_ages.append(0.0)
		_respawn(i)
		# Spread along their paths, so the whirlpool is already turning the
		# first time the map opens.
		_advance(i, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, 2.5))


func _process(delta: float) -> void:
	_time += delta
	if layer == Layer.MOTES:
		for i: int in range(_active_motes()):
			_advance(i, delta)
	queue_redraw()


func _draw() -> void:
	if layer == Layer.HALO:
		_draw_halo()
	else:
		_draw_motes()


func _draw_halo() -> void:
	var open: bool = _gate_open()
	var swell: float = 1.0 + 0.1 * sin(_time * TAU / _PULSE_SECONDS)
	var strength: float = 1.6 if open else 1.0
	for ring: Vector2 in _HALO_RINGS:
		draw_circle(Vector2.ZERO, roundf(ring.x * swell), Color(_CYAN, ring.y * strength), true, -1.0, false)
	# The beat: a thin ring that swells out and fades, like the gate drawing
	# breath. Twice as often once it's open.
	var beat_period: float = _BEAT_SECONDS * (0.5 if open else 1.0)
	var beat: float = fmod(_time, beat_period) / beat_period
	if beat < 0.5:
		var t: float = beat / 0.5
		draw_arc(Vector2.ZERO, roundf(lerpf(10.0, 22.0, t)), 0.0, TAU, 32,
				Color(_WHITE, 0.45 * (1.0 - t)), 1.0, false)


func _draw_motes() -> void:
	for i: int in range(_active_motes()):
		var at: Vector2 = Vector2.from_angle(_angles[i]) * _radii[i]
		var near: float = 1.0 - clampf((_radii[i] - _SWALLOW_RADIUS) / _SPAWN_RADIUS.y, 0.0, 1.0)
		var alpha: float = clampf(_ages[i] / 0.4, 0.0, 1.0) * (0.7 + 0.3 * near)
		var color: Color = _BLUE.lerp(_WHITE, near)
		var pixel: Vector2 = at.round()
		draw_rect(Rect2(pixel - Vector2(0.5, 0.5), Vector2.ONE), Color(color, alpha))
		# A short tail back the way it came, a little longer as it speeds up.
		var lag: float = 0.06
		var behind: Vector2 = Vector2.from_angle(_angles[i] - _swirl_at(_radii[i]) * lag) \
				* (_radii[i] + _speeds[i] * lag)
		var tail: Vector2 = (behind - at).limit_length(_MAX_TAIL)
		draw_line((at + tail).round(), pixel, Color(_CYAN, alpha * 0.6), 1.0, false)


func _advance(i: int, delta: float) -> void:
	var accel: float = _OPEN_ACCEL if _gate_open() else _ACCEL
	_speeds[i] += accel * delta
	_ages[i] += delta
	_radii[i] -= _speeds[i] * delta
	_angles[i] += _swirl_at(_radii[i]) * delta
	if _radii[i] <= _SWALLOW_RADIUS:
		_respawn(i)


## Angular speed at [param radius]: faster the closer in, like water at a drain.
func _swirl_at(radius: float) -> float:
	return _SWIRL * _SPAWN_RADIUS.y / maxf(radius, _SWALLOW_RADIUS)


func _respawn(i: int) -> void:
	_angles[i] = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
	_radii[i] = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, _SPAWN_RADIUS.x, _SPAWN_RADIUS.y)
	_speeds[i] = _START_SPEED
	_ages[i] = 0.0


func _active_motes() -> int:
	return _OPEN_MOTES if _gate_open() else _MOTES


func _gate_open() -> bool:
	return Globals.jump_gate != null and Globals.jump_gate.is_open()
