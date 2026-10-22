class_name FateStorm
extends HazardTelegraph
## Fate's weather. The sky near Fate never settles: sheet lightning lights it
## from behind, jagged bolts crack across it, and now and then Fate tears
## straight through it in bands of static. Every flash also lights the
## shards drifting past (through the global fate_flash that
## fate_corruption.gdshader reads), so the whole field shudders with it.
##
## It quickens when the rift is about to open and breaks into a barrage when
## it does. Anywhere without a hazard it just keeps its calm rhythm.
##
## Draws one screen of art pixels from its own origin, so place it at (0, 0).
## It sits above the stars and set pieces and below the scrolling pieces,
## which is what silhouettes the shards against a flash.

enum Kind { SHEET, BOLT, TEAR }

## Seconds between strikes, picked fresh each time: at rest, and while the
## rift is about to open.
@export var calm_gap: Vector2 = Vector2(1.4, 4.0)
@export var urgent_gap: Vector2 = Vector2(0.45, 1.2)
## Relative odds of each kind of strike.
@export var sheet_weight: float = 5.0
@export var bolt_weight: float = 4.0
@export var tear_weight: float = 1.5
## How strongly a bolt's faint wash reaches the whole screen, cockpit and UI
## included. 0 keeps the storm inside the viewer.
@export_range(0.0, 0.3) var screen_wash: float = 0.05
## False leaves strikes to strike() and strike_from() alone, for a scene
## that times its own lightning.
@export var autonomous: bool = true

## Approved palette.
const _SHEET_SKY: Color = Color("#463c91")
const _BOLT_SKY: Color = Color("#80359d")
const _CORE: Color = Color("#cef0f1")
const _HOT: Color = Color("#c552f1")
const _GLOW: Color = Color("#80359d")

## How long each kind of strike lights the sky, in seconds.
const _LIFETIMES: Dictionary[Kind, float] = {Kind.SHEET: 0.7, Kind.BOLT: 0.5, Kind.TEAR: 0.3}
## Bolts step this many art pixels between kinks.
const _BOLT_STEP: Vector2 = Vector2(3.0, 7.0)

class Strike:
	var kind: Kind
	var age: float = 0.0
	var strength: float = 1.0
	## BOLT only: the lit pixels, and the pixels glowing around them.
	var core: Array[Vector2i] = []
	var glow: Array[Vector2i] = []

var _strikes: Array[Strike] = []
var _countdown: float = 0.0

@onready var _sky: ColorRect = $Sky
@onready var _tear: ColorRect = $Tear
@onready var _tear_material: ShaderMaterial = _tear.material as ShaderMaterial


func _ready() -> void:
	super()
	_countdown = _next_gap()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"fate_flash", 0.0)


func _process(delta: float) -> void:
	if autonomous:
		_countdown -= delta
		if _countdown <= 0.0:
			_countdown = _next_gap()
			_strike_random()

	for active: Strike in _strikes:
		active.age += delta
	_strikes = _strikes.filter(func(s: Strike) -> bool: return s.age < _LIFETIMES[s.kind])
	_show()


## Lightning on demand: a sheet flash, a bolt or a tear, at [param strength].
func strike(kind: Kind, strength: float = 1.0) -> void:
	var new_strike: Strike = Strike.new()
	new_strike.kind = kind
	new_strike.strength = strength
	if kind == Kind.BOLT:
		var start: Vector2 = Vector2(_randf(8.0, Globals.SCREEN_SIZE.x - 8.0), -1.0)
		_build_bolt(new_strike, start, PI / 2.0 + _randf(-0.5, 0.5), _randf(70.0, 150.0), 2)
	elif kind == Kind.TEAR:
		_tear_material.set_shader_parameter("seed", _randf(0.0, 100.0))
	_begin(new_strike)


## Bolts that crack outward from [param origin], as if thrown off by it.
func strike_from(origin: Vector2, bolts: int = 3, strength: float = 1.0) -> void:
	for i: int in range(bolts):
		var new_strike: Strike = Strike.new()
		new_strike.kind = Kind.BOLT
		new_strike.strength = strength
		var angle: float = TAU * (float(i) + _randf(0.0, 0.7)) / float(bolts)
		_build_bolt(new_strike, origin, angle, _randf(40.0, 90.0), 1)
		_begin(new_strike)


func _urgency_changed() -> void:
	_countdown = minf(_countdown, _next_gap())


## The rift opening: a barrage of bolts with a tear through the middle.
func _fired() -> void:
	strike(Kind.TEAR, 1.0)
	for i: int in range(3):
		strike(Kind.BOLT, 1.0)
	Juice.screen_flash(self, _HOT, screen_wash * 3.0, 0.35)


func _strike_random() -> void:
	var roll: float = _randf(0.0, sheet_weight + bolt_weight + tear_weight)
	if roll < sheet_weight:
		strike(Kind.SHEET, _randf(0.5, 1.0))
	elif roll < sheet_weight + bolt_weight:
		strike(Kind.BOLT, 1.0)
	else:
		strike(Kind.TEAR, _randf(0.5, 1.0))


func _begin(new_strike: Strike) -> void:
	_strikes.append(new_strike)
	if new_strike.kind == Kind.BOLT and screen_wash > 0.0:
		Juice.screen_flash(self, _HOT, screen_wash * new_strike.strength, 0.2)


func _next_gap() -> float:
	var gap: Vector2 = urgent_gap if urgent else calm_gap
	return _randf(gap.x, gap.y)


# --- Light ------------------------------------------------------------------

## How lit the sky is by [param strike] right now, 0 to 1. Bolts stutter:
## a flash, a blink of dark, a second flash, then a fade. Sheet lightning
## rolls in two humps, like light behind cloud.
func _light(strike_now: Strike) -> float:
	var t: float = strike_now.age
	var level: float = 0.0
	match strike_now.kind:
		Kind.BOLT:
			level = exp(-t / 0.14)
			if t > 0.05 and t < 0.09:
				level *= 0.15
		Kind.SHEET:
			level = 0.6 * exp(-t / 0.12)
			if t > 0.14:
				level = maxf(level, exp(-(t - 0.14) / 0.2))
		Kind.TEAR:
			level = 0.0
	return clampf(level * strike_now.strength, 0.0, 1.0)


func _show() -> void:
	var sky_level: float = 0.0
	var sky_color: Color = _SHEET_SKY
	var coverage: float = 0.0
	for strike_now: Strike in _strikes:
		var level: float = _light(strike_now)
		if level > sky_level:
			sky_level = level
			sky_color = _BOLT_SKY if strike_now.kind == Kind.BOLT else _SHEET_SKY
		if strike_now.kind == Kind.TEAR:
			# Two stutters of tearing, the second thinner.
			var torn: float = 0.32 if strike_now.age < 0.14 else 0.14
			coverage = maxf(coverage, torn * strike_now.strength)

	# The sky rect blends additively, so its alpha is how much light it adds.
	_sky.color = Color(sky_color, sky_level * 0.45)
	_tear.visible = coverage > 0.0
	_tear_material.set_shader_parameter("coverage", coverage)
	RenderingServer.global_shader_parameter_set(&"fate_flash", sky_level)
	queue_redraw()


func _draw() -> void:
	for strike_now: Strike in _strikes:
		if strike_now.kind != Kind.BOLT:
			continue
		var level: float = _light(strike_now)
		if level <= 0.05:
			continue
		# White-hot only for the first instant, then Fate's purple.
		var core: Color = _CORE if strike_now.age < 0.05 else _HOT
		for pixel: Vector2i in strike_now.glow:
			draw_rect(Rect2(pixel, Vector2.ONE), Color(_GLOW, level * 0.8))
		for pixel: Vector2i in strike_now.core:
			draw_rect(Rect2(pixel, Vector2.ONE), Color(core, minf(1.0, level * 1.5)))


# --- Bolt shape -------------------------------------------------------------

## Walks a jagged line from [param start] heading roughly [param angle] for
## [param length] art pixels, forking off up to [param forks] shorter
## branches, and fills in the strike's core and glow pixels.
func _build_bolt(target: Strike, start: Vector2, angle: float, length: float, forks: int) -> void:
	var lit: Dictionary[Vector2i, bool] = {}
	_walk(lit, start, angle, length, forks)
	for pixel: Vector2i in lit:
		target.core.append(pixel)
	var halo: Dictionary[Vector2i, bool] = {}
	for pixel: Vector2i in lit:
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbour: Vector2i = pixel + offset
			if not lit.has(neighbour):
				halo[neighbour] = true
	for pixel: Vector2i in halo:
		target.glow.append(pixel)


func _walk(lit: Dictionary[Vector2i, bool], from: Vector2, angle: float, length: float, forks: int) -> void:
	var position_now: Vector2 = from
	var travelled: float = 0.0
	while travelled < length:
		var step_length: float = _randf(_BOLT_STEP.x, _BOLT_STEP.y)
		var heading: float = angle + _randf(-0.6, 0.6)
		var next: Vector2 = position_now + Vector2.from_angle(heading) * step_length
		_line(lit, Vector2i(position_now.round()), Vector2i(next.round()))
		position_now = next
		travelled += step_length
		if forks > 0 and _randf(0.0, 1.0) < 0.25:
			forks -= 1
			var side: float = 1.0 if _randf(0.0, 1.0) < 0.5 else -1.0
			_walk(lit, position_now, angle + side * _randf(0.4, 0.9), (length - travelled) * 0.5, 0)


## Bresenham, so a bolt is one clean pixel wide however it bends.
func _line(lit: Dictionary[Vector2i, bool], a: Vector2i, b: Vector2i) -> void:
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


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
