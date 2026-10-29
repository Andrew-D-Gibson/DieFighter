class_name FateRiftTear
extends HazardTelegraph
## A tear in space that Fate keeps working at. It rips longer and prises
## open, holds, then knits back to a glowing seam, on an uneven breath so it
## never settles into a metronome. Opening throws sparks off its lips;
## closing drags loose scrap back in.
##
## fate_rift_tear.gdshader draws the tear from the shape this feeds it every
## frame. The sparks are drawn here, a pixel each, from the same lips.
##
## Once the rift is about to open it strains wider and breathes faster; the
## build-up tears it wide, and the strike blazes it open past its limit.

enum Phase { RESTING, OPENING, HOLDING, CLOSING }

## Half its length in art pixels, ripped back to and ripped out to.
@export var half_length: Vector2 = Vector2(14.0, 34.0)
## How far either lip pulls from the spine when fully open, in art pixels.
@export var half_width_max: float = 7.0

@export_group("Breath")
## Each range is picked from fresh every breath, so no two are alike.
## How open it rests and how open it gets, as shares of half_width_max.
@export var rest_open: Vector2 = Vector2(0.0, 0.12)
@export var peak_open: Vector2 = Vector2(0.35, 1.0)
## While the rift is about to open: it gapes wider...
@export var urgent_peak_open: Vector2 = Vector2(0.75, 1.0)
## ...and breathes this many times faster.
@export var urgent_speed: float = 2.2
## Seconds spent in each phase.
@export var rest_seconds: Vector2 = Vector2(0.8, 3.2)
@export var open_seconds: Vector2 = Vector2(1.2, 3.0)
@export var hold_seconds: Vector2 = Vector2(0.3, 1.6)
@export var close_seconds: Vector2 = Vector2(1.6, 3.4)

## The tear's spine, x = a1 sin(y f1 + p1) + a2 sin(y f2 + p2): the S-curve
## the original painted tear had. Fixed, so it is always the same tear.
const SPINE: Vector4 = Vector4(-2.6, 0.11, 0.9, 0.31)
const SPINE_PHASE: Vector2 = Vector2(1.9, 0.4)

## How far a strike forces it past fully open.
const _STRIKE_OPEN: float = 1.2
const _STRIKE_SPARKS: int = 28
## Sparks per second at full tearing energy, and the most alive at once.
const _SPARK_RATE: float = 30.0
const _MAX_SPARKS: int = 64
## Scrap dragged back in per second while it closes.
const _DEBRIS_RATE: float = 4.0

## Approved palette.
const _SPARK_HOT: Color = Color("#cef0f1")
const _SPARK_WARM: Color = Color("#c552f1")
const _SPARK_COOL: Color = Color("#80359d")
const _DEBRIS_COLORS: Array[Color] = [Color("#8e8b85"), Color("#63605c"), Color("#463c91")]

class Spark:
	var position: Vector2
	var velocity: Vector2
	var age: float = 0.0
	var life: float = 0.5
	## Scrap being drawn in rather than a spark flung out.
	var debris_color: Color = Color.TRANSPARENT

var _phase: Phase = Phase.RESTING
var _phase_age: float = 0.0
var _phase_seconds: float = 1.0
var _from_open: float = 0.0
var _to_open: float = 0.0
var _from_reach: float = 0.0
var _to_reach: float = 0.0

## The tear's shape right now, as the shader sees it.
var _open: float = 0.0
var _reach: float = 0.3
var _energy: float = 0.0
var _glow: float = 0.0
var _glow_tween: Tween
## Torn wide by the build-up: holds there until the strike rather than
## closing on its own.
var _held_for_strike: bool = false

var _time: float = 0.0
var _sparks: Array[Spark] = []
var _spark_debt: float = 0.0
var _debris_debt: float = 0.0

@onready var _tear: ColorRect = $Tear
@onready var _material: ShaderMaterial = _tear.material as ShaderMaterial


func _ready() -> void:
	super()
	_material.set_shader_parameter("spine", SPINE)
	_material.set_shader_parameter("spine_phase", SPINE_PHASE)
	_material.set_shader_parameter("half_length", half_length)
	_material.set_shader_parameter("half_width_max", half_width_max)
	_material.set_shader_parameter("seed", _randf(0.0, 100.0))
	_material.set_shader_parameter("size", _tear.size)
	# Start somewhere in a breath, so two visits don't open identically.
	_open = _randf(rest_open.x, rest_open.y)
	_reach = 0.2
	_begin(Phase.RESTING, _randf(0.0, rest_seconds.y))


func _process(delta: float) -> void:
	_time += delta
	var before: float = _open
	_breathe(delta * (urgent_speed if urgent else 1.0))
	# How fast it is tearing, smoothed so the crackle swells rather than blinks.
	var rate: float = maxf(0.0, _open - before) / maxf(delta, 0.0001)
	_energy = lerpf(_energy, clampf(rate * 1.5, 0.0, 1.0), minf(1.0, delta * 6.0))

	_material.set_shader_parameter("open", _shown_open())
	_material.set_shader_parameter("reach", _reach)
	_material.set_shader_parameter("energy", _energy)
	_material.set_shader_parameter("glow", _glow)
	_material.set_shader_parameter("calm", 1.0 if Globals.reduce_flashing else 0.0)

	_spawn_sparks(delta)
	_move_sparks(delta)
	queue_redraw()


func _draw() -> void:
	for spark: Spark in _sparks:
		var at: Vector2 = spark.position.floor()
		if spark.debris_color.a > 0.0:
			draw_rect(Rect2(at, Vector2.ONE), spark.debris_color)
			continue
		var share: float = spark.age / spark.life
		var color: Color = _SPARK_HOT if share < 0.3 else (_SPARK_WARM if share < 0.65 else _SPARK_COOL)
		# A fast spark smears one pixel behind it.
		if spark.velocity.length() > 18.0:
			var behind: Vector2 = (spark.position - spark.velocity.normalized()).floor()
			if behind != at:
				draw_rect(Rect2(behind, Vector2.ONE), _SPARK_COOL)
		draw_rect(Rect2(at, Vector2.ONE), color)


# --- Shape ------------------------------------------------------------------

## The spine's x at art-pixel row [param y] (from the tear's centre). The
## shader's spine_x(), with the same constants.
static func spine_x(y: float) -> float:
	return SPINE.x * sin(y * SPINE.y + SPINE_PHASE.x) + SPINE.z * sin(y * SPINE.w + SPINE_PHASE.y)


## How far one lip sits from the spine at row [param y], before the shader's
## ragged bite: lens-shaped, widest mid-tear and shut at the tips.
func lip_offset(y: float) -> float:
	var v: float = y / _half_length_now()
	if v * v >= 1.0:
		return 0.0
	return _shown_open() * half_width_max * pow(1.0 - v * v, 0.6)


func _half_length_now() -> float:
	return lerpf(half_length.x, half_length.y, _reach)


## The open share with a faint tremor on it, so even a held tear strains.
func _shown_open() -> float:
	return _open * (1.0 + 0.06 * sin(_time * 9.1) * sin(_time * 3.7))


# --- Breath -----------------------------------------------------------------

func _breathe(delta: float) -> void:
	_phase_age += delta
	var t: float = clampf(_phase_age / _phase_seconds, 0.0, 1.0)
	match _phase:
		Phase.OPENING:
			# Rips in jolts rather than one smooth pull, and runs longer
			# before it gapes: the length leads, the width follows.
			var jolted: float = t + 0.04 * sin(t * TAU * 3.0)
			_open = lerpf(_from_open, _to_open, smoothstep(0.0, 1.0, jolted))
			_reach = lerpf(_from_reach, _to_reach, ease(minf(1.0, t * 1.6), 0.4))
		Phase.CLOSING:
			# The width knits first; the length heals once it has.
			_open = lerpf(_from_open, _to_open, smoothstep(0.0, 1.0, t))
			_reach = lerpf(_from_reach, _to_reach, smoothstep(0.3, 1.0, t))
	if t >= 1.0:
		_next_phase()


func _next_phase() -> void:
	match _phase:
		Phase.RESTING:
			_begin(Phase.OPENING, _randf(open_seconds.x, open_seconds.y))
			var peak: Vector2 = urgent_peak_open if urgent else peak_open
			_to_open = _randf(peak.x, peak.y)
			# A wide breath rips long; a shallow one barely lengthens.
			_to_reach = clampf(0.25 + 0.75 * _to_open + _randf(-0.1, 0.1), 0.0, 1.0)
		Phase.OPENING:
			var hold: float = 30.0 if _held_for_strike else _randf(hold_seconds.x, hold_seconds.y)
			_begin(Phase.HOLDING, hold)
		Phase.HOLDING:
			_begin(Phase.CLOSING, _randf(close_seconds.x, close_seconds.y))
			_to_open = _randf(rest_open.x, rest_open.y)
			_to_reach = _randf(0.0, 0.3)
		Phase.CLOSING:
			_begin(Phase.RESTING, _randf(rest_seconds.x, rest_seconds.y))


func _begin(phase: Phase, seconds: float) -> void:
	_phase = phase
	_phase_age = 0.0
	_phase_seconds = maxf(seconds, 0.05)
	_from_open = _open
	_from_reach = _reach
	_to_open = _open
	_to_reach = _reach


## Forces a breath to [param open] and full length over [param seconds].
func _tear_open(open: float, seconds: float) -> void:
	_begin(Phase.OPENING, seconds)
	_to_open = open
	_to_reach = 1.0


# --- Sparks -----------------------------------------------------------------

func _spawn_sparks(delta: float) -> void:
	var calm_share: float = 0.5 if Globals.reduce_flashing else 1.0
	var rate: float = _SPARK_RATE * _energy * calm_share
	# A tear held wide still spits now and then.
	if _open > 0.4:
		rate += 1.5 * calm_share
	_spark_debt += rate * delta
	while _spark_debt >= 1.0:
		_spark_debt -= 1.0
		_add_spark()

	if _phase == Phase.CLOSING and _open > 0.15:
		_debris_debt += _DEBRIS_RATE * delta
		while _debris_debt >= 1.0:
			_debris_debt -= 1.0
			_add_debris()


func _add_spark() -> void:
	if _sparks.size() >= _MAX_SPARKS:
		return
	var y: float = _randf(-0.85, 0.85) * _half_length_now()
	var side: float = 1.0 if _randf(0.0, 1.0) < 0.5 else -1.0
	var spark: Spark = Spark.new()
	spark.position = Vector2(spine_x(y) + side * (lip_offset(y) + 1.0), y)
	spark.velocity = Vector2(side * _randf(14.0, 34.0), _randf(-12.0, 12.0))
	spark.life = _randf(0.25, 0.6)
	_sparks.append(spark)


## A bit of scrap a few pixels off a lip, falling in toward the spine.
func _add_debris() -> void:
	if _sparks.size() >= _MAX_SPARKS:
		return
	var y: float = _randf(-0.7, 0.7) * _half_length_now()
	var side: float = 1.0 if _randf(0.0, 1.0) < 0.5 else -1.0
	var lip: float = lip_offset(y)
	var spark: Spark = Spark.new()
	var distance: float = _randf(5.0, 10.0)
	spark.position = Vector2(spine_x(y) + side * (lip + distance), y)
	var speed: float = _randf(8.0, 16.0)
	spark.velocity = Vector2(-side * speed, -y * 0.15)
	spark.life = distance / speed
	spark.debris_color = RNGManager.pick_random(RNGManager.Bucket.COSMETIC, _DEBRIS_COLORS)
	_sparks.append(spark)


func _move_sparks(delta: float) -> void:
	for spark: Spark in _sparks:
		spark.age += delta
		spark.position += spark.velocity * delta
		# Sparks bleed off speed; scrap is pulled ever faster.
		spark.velocity *= (1.0 + delta * 1.5) if spark.debris_color.a > 0.0 else (1.0 - delta * 2.5)
	_sparks = _sparks.filter(func(s: Spark) -> bool: return s.age < s.life)


# --- Hazard beats -----------------------------------------------------------

func _urgency_changed() -> void:
	if not urgent:
		# The hazard reset or the fight ended: let a held tear breathe again.
		_held_for_strike = false
	# Don't sit out a long rest once the rift is straining.
	if urgent and _phase == Phase.RESTING:
		_phase_seconds = minf(_phase_seconds, _phase_age + rest_seconds.x)


## The build-up tears it wide and lights it toward the strike.
func _winding_up(seconds: float) -> void:
	_tear_open(1.0, seconds * 0.9)
	_held_for_strike = true
	_tween_glow(0.45, seconds, Tween.EASE_IN)


## The strike: ripped past its limit, a blaze, and a burst of sparks.
func _fired() -> void:
	_held_for_strike = false
	_tear_open(_STRIKE_OPEN, 0.12)
	_glow = Juice.soften_flash(1.0)
	_tween_glow(0.0, 1.2, Tween.EASE_OUT)
	var burst: int = _STRIKE_SPARKS / 2 if Globals.reduce_flashing else _STRIKE_SPARKS
	for i: int in range(burst):
		_add_spark()


func _tween_glow(level: float, seconds: float, easing: Tween.EaseType) -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_property(self, "_glow", Juice.soften_flash(level), seconds) \
		.set_trans(Tween.TRANS_EXPO).set_ease(easing)


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
