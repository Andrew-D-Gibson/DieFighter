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
const _LIFETIMES: Dictionary[Kind, float] = {Kind.SHEET: 0.7, Kind.BOLT: 0.7, Kind.TEAR: 0.3}
## A bolt's dark blink between its two strikes, in seconds from its start,
## and when its second strike starts to fade.
const _BOLT_BLINK: Vector2 = Vector2(0.06, 0.1)
const _BOLT_HOLD: float = 0.22

class Strike:
	var kind: Kind
	var age: float = 0.0
	var strength: float = 1.0
	## BOLT only: its shape.
	var bolt: LightningBolt = null

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
		new_strike.bolt = LightningBolt.grow(start, PI / 2.0 + _randf(-0.5, 0.5), _randf(70.0, 150.0), 2)
	elif kind == Kind.TEAR:
		_tear_material.set_shader_parameter("seed", _randf(0.0, 100.0))
	_begin(new_strike)


## Bolts that crack outward from [param origin] (in this node's space), as if
## thrown off by it. Each starts [param inner_radius] out, past whatever body
## sits there, and reaches up to [param reach] art pixels further.
func strike_from(origin: Vector2, bolts: int = 3, reach: float = 70.0, inner_radius: float = 0.0, strength: float = 1.0) -> void:
	for i: int in range(bolts):
		var new_strike: Strike = Strike.new()
		new_strike.kind = Kind.BOLT
		new_strike.strength = strength
		var angle: float = TAU * (float(i) + _randf(0.0, 0.7)) / float(bolts)
		var start: Vector2 = origin + Vector2.from_angle(angle) * inner_radius
		new_strike.bolt = LightningBolt.grow(start, angle, _randf(reach * 0.6, reach), 1)
		_begin(new_strike)


func _urgency_changed() -> void:
	_countdown = minf(_countdown, _next_gap())


## Sheet lightning rolls in faster and faster as the storm gathers.
func _winding_up(seconds: float) -> void:
	# When, as fractions of the build-up.
	var beats: Array[float] = [0.1, 0.4, 0.65, 0.85]
	for at: float in beats:
		get_tree().create_timer(seconds * at, false).timeout.connect(
			func() -> void: strike(Kind.SHEET, lerpf(0.5, 1.0, at))
		)


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

## How lit the sky is by [param strike] right now, 0 to 1. Bolts strike
## twice: a flash, a blink of dark, a second flash that holds, then a fade.
## Sheet lightning rolls in two humps, like light behind cloud.
func _light(strike_now: Strike) -> float:
	var t: float = strike_now.age
	var level: float = 0.0
	match strike_now.kind:
		Kind.BOLT:
			if t < _BOLT_BLINK.x:
				level = 1.0
			elif t < _BOLT_BLINK.y:
				level = 0.15
			elif t < _BOLT_HOLD:
				level = 1.0
			else:
				level = exp(-(t - _BOLT_HOLD) / 0.12)
		Kind.SHEET:
			level = 0.6 * exp(-t / 0.12)
			if t > 0.14:
				level = maxf(level, exp(-(t - 0.14) / 0.2))
		Kind.TEAR:
			level = 0.0
	# Reduce Flashing keeps the storm's lightning but dims it well down.
	return clampf(level * strike_now.strength, 0.0, 1.0) * Juice.soften_flash(1.0)


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
		# White-hot only while each strike lands, then Fate's purple.
		var age: float = strike_now.age
		var landing: bool = age < _BOLT_BLINK.x or (age > _BOLT_BLINK.y and age < _BOLT_BLINK.y + 0.05)
		var core: Color = _CORE if landing else _HOT
		strike_now.bolt.draw_on(self, Color(core, minf(1.0, level * 1.5)), Color(_GLOW, level * 0.8))


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
