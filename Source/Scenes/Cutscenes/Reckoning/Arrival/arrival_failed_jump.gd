class_name ArrivalFailedJump
extends Node2D
## A ship left behind in the Reckoning, trying to follow (RECKONING_ENDINGS.md
## §6, The formation): charge motes gather at its slot, a jump flare starts,
## stutters... and nothing arrives. The motes drift apart. No body, no wreck:
## only the effort to reach you. Drawn a pixel at a time on the 320x180 grid;
## frees itself when the motes are gone.

## Seconds the motes take to gather, the flare to stutter out, and the motes
## to drift apart.
const GATHER_SECONDS: float = 1.5
const STUTTER_SECONDS: float = 1.1
const DRIFT_SECONDS: float = 2.4

const _MOTES: int = 12
const _GATHER_RADIUS: float = 19.0
const _CORE_RADIUS: float = 3.0
## The flare's stutter, one entry per tenth of a second: how bright it gets.
## It catches, fails, catches weaker, fails, and is gone.
const _STUTTER: PackedFloat32Array = [0.5, 1.0, 0.0, 0.0, 0.8, 0.2, 0.0, 0.5, 0.0, 0.25, 0.0]
## How far the jump's wake gets in from the left before it breaks up, as a
## share of the way to the slot.
const _WAKE_REACH: float = 0.35
const _FAIL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres")

## The ship's faction colour: the jump it would have come out of.
var color: Color = Color.WHITE

var _age: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
var _drift: Array[Vector2] = []
var _sounded: bool = false


func _ready() -> void:
	for i: int in _MOTES:
		_angles.append(TAU * i / _MOTES + _randf(-0.25, 0.25))
		# Each mote leaves in its own direction, slowly: they lose each other.
		_drift.append(Vector2.from_angle(_randf(0.0, TAU)) * _randf(3.0, 9.0))


func _process(delta: float) -> void:
	_age += delta
	if not _sounded and _age >= GATHER_SECONDS:
		_sounded = true
		Events.play_sound.emit(_FAIL_SFX)
	if _age >= GATHER_SECONDS + STUTTER_SECONDS + DRIFT_SECONDS:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var stutter_start: float = GATHER_SECONDS
	var drift_start: float = GATHER_SECONDS + STUTTER_SECONDS
	if _age < stutter_start:
		var t: float = _age / GATHER_SECONDS
		var radius: float = lerpf(_GATHER_RADIUS, _CORE_RADIUS, 1.0 - pow(1.0 - t, 2.0))
		for i: int in _MOTES:
			# A slow turn as they close in: drawn by the drive, not thrown.
			var at: Vector2 = Vector2.from_angle(_angles[i] + t * 1.2) * radius
			_pixel(at, Color(color, clampf(t * 2.0, 0.0, 1.0)))
	elif _age < drift_start:
		var into: float = _age - stutter_start
		var beat: int = mini(int(into * 10.0), _STUTTER.size() - 1)
		var light: float = _STUTTER[beat]
		for i: int in _MOTES:
			_pixel(Vector2.from_angle(_angles[i] + 1.2) * _CORE_RADIUS, Color(color, 0.6 + 0.4 * light))
		if light > 0.0:
			_draw_flare(light)
			_draw_wake(light)
	else:
		var t: float = (_age - drift_start) / DRIFT_SECONDS
		for i: int in _MOTES:
			var start: Vector2 = Vector2.from_angle(_angles[i] + 1.2) * _CORE_RADIUS
			var at: Vector2 = start + _drift[i] * (_age - drift_start)
			_pixel(at, Color(color, 0.7 * (1.0 - t)))


## The flare at the heart of the jump, as bright as [param light] lets it.
func _draw_flare(light: float) -> void:
	var reach: int = roundi(light * 5.0)
	var core: Color = Color.WHITE.lerp(color, 0.3)
	for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_pixel(offset, Color(core, light))
	for step: int in range(1, reach + 1):
		var shade: Color = Color(color, light * (1.0 - float(step) / (reach + 1)))
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_pixel(direction * step, shade)


## The wake a jump leaves, started in from the left edge of the frame and
## breaking up long before it reaches the slot.
func _draw_wake(light: float) -> void:
	var from: Vector2 = Vector2(-global_position.x - 4.0, 0.0)
	var reach: float = -from.x * _WAKE_REACH * light
	for x: int in range(int(reach)):
		# Broken, every few pixels missing: the signal isn't holding.
		if (x + int(_age * 30.0)) % 5 == 0:
			continue
		var t: float = float(x) / maxf(reach, 1.0)
		_pixel(from + Vector2(x, 0), Color(color, light * 0.5 * (1.0 - t)))


func _pixel(at: Vector2, shade: Color) -> void:
	draw_rect(Rect2(at.round(), Vector2.ONE), shade)


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
