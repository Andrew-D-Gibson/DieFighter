class_name JuiceKillFocus
extends Node2D
## The held frame of a kill: the world dims and speed lines rush in on the
## dying ship, then both cut away the instant time resumes. Spawned through
## Juice.kill_focus().
##
## It runs on effect time throughout, because it plays inside a hitstop. A freeze
## where nothing moves reads as the game hitching; a freeze where the frame
## itself is still charging reads as impact.

## How dark the world gets behind the ship.
const _DIM_COLOR: Color = Color(0.0, 0.0, 0.03, 0.62)
const _DIM_IN_SECONDS: float = 0.04
const _DIM_OUT_SECONDS: float = 0.12
## Far enough to cover the screen at any zoom the kill cam reaches.
const _DIM_EXTENT: float = 600.0

const _LINE_COUNT: int = 24
## How close the lines' tips get to the ship's centre, at the end of the hold.
## They close in from there, so the frame tightens on the ship rather than
## sitting still.
const _LINE_INNER_START: float = 46.0
const _LINE_INNER_END: float = 24.0
const _LINE_INNER_JITTER: float = 10.0
## Just past the screen corners at the kill cam's zoom: any further and the
## wide ends of the wedges are all offscreen, leaving only thin slivers.
const _LINE_OUTER: float = 170.0
## Shares of the hold the lines spend shooting in from offscreen, and then
## with their tails chasing the tips in until they vanish into the ship. They
## sit at full length in between.
const _LINE_EXTEND_SHARE: float = 0.35
const _LINE_RETRACT_SHARE: float = 0.3
const _LINE_MIN_WIDTH: float = 4.0
const _LINE_MAX_WIDTH: float = 12.0
## Redrawn this often rather than every frame: a flicker on twos reads as
## hand-drawn, a fresh set every frame reads as noise.
const _REROLL_MSEC: int = 50
## Share of lines drawn in the accent color rather than white.
const _ACCENT_SHARE: float = 0.25

## The hit spark behind the ship: a jagged star whose points peek out round
## the silhouette. Each spike is rerolled with the lines.
const _SPARK_POINTS: int = 9
const _SPARK_INNER: float = 10.0
const _SPARK_OUTER_MIN: float = 22.0
const _SPARK_OUTER_MAX: float = 38.0
## The white core's size against the accent star around it.
const _SPARK_CORE_SCALE: float = 0.6

## Only the first focus on screen dims. Kills that land together would
## otherwise stack their dims until the screen went black.
const _DIM_GROUP: StringName = &"juice_kill_dim"

var hold_seconds: float = 0.25
var accent: Color = Color.RED

var _draws_dim: bool = true
var _started_msec: float = 0.0
var _last_reroll_msec: float = -_REROLL_MSEC
var _released: bool = false
var _dim_alpha: float = 0.0
## Each line as [angle, inner offset, width, is_accent].
var _lines: Array[Array] = []
## The hit spark's outline, as alternating outer and inner points.
var _spark: PackedVector2Array = PackedVector2Array()
## Its own stream, not RNGManager: purely cosmetic, so a seeded run replays the
## same with or without it.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_draws_dim = get_tree().get_nodes_in_group(_DIM_GROUP).is_empty()
	if _draws_dim:
		add_to_group(_DIM_GROUP)
	_started_msec = TimeDirector.effect_msec()
	# The first draw can land before the first process, and an empty spark
	# isn't a polygon.
	_last_reroll_msec = 0
	_reroll_lines()


func _process(_delta: float) -> void:
	var elapsed_msec: float = TimeDirector.effect_msec() - _started_msec
	if not _released and elapsed_msec >= hold_seconds * 1000.0:
		_release()
	if _released:
		return

	_dim_alpha = clampf(elapsed_msec / (_DIM_IN_SECONDS * 1000.0), 0.0, 1.0)
	if elapsed_msec - _last_reroll_msec >= _REROLL_MSEC:
		_last_reroll_msec = elapsed_msec
		_reroll_lines()
	queue_redraw()


func _draw() -> void:
	if _draws_dim and _dim_alpha > 0.0:
		var dim: Color = Color(_DIM_COLOR, _DIM_COLOR.a * _dim_alpha)
		draw_rect(Rect2(-Vector2.ONE * _DIM_EXTENT, Vector2.ONE * _DIM_EXTENT * 2.0), dim)
	if _released:
		return

	var progress: float = clampf((TimeDirector.effect_msec() - _started_msec) / (hold_seconds * 1000.0), 0.0, 1.0)
	var inner_base: float = lerpf(_LINE_INNER_START, _LINE_INNER_END, progress)
	# Eased out on the way in, so they strike rather than slide; eased in on
	# the way out, so they're gone in a snap on the frame time resumes.
	var extend: float = ease(clampf(progress / _LINE_EXTEND_SHARE, 0.0, 1.0), 0.4)
	var retract: float = ease(clampf((progress - (1.0 - _LINE_RETRACT_SHARE)) / _LINE_RETRACT_SHARE, 0.0, 1.0), 2.0)
	for line: Array in _lines:
		var direction: Vector2 = Vector2.from_angle(line[0])
		var side: Vector2 = direction.orthogonal() * (line[2] / 2.0)
		var inner: float = inner_base + line[1]
		var tip_distance: float = lerpf(_LINE_OUTER, inner, extend)
		var outer_distance: float = lerpf(_LINE_OUTER, inner, retract)
		if outer_distance - tip_distance < 1.0:
			continue
		var tip: Vector2 = direction * tip_distance
		var outer: Vector2 = direction * outer_distance
		var color: Color = accent if line[3] else Color.WHITE
		draw_colored_polygon(PackedVector2Array([tip, outer + side, outer - side]), color)

	draw_colored_polygon(_spark, accent)
	var core: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _spark:
		core.append(point * _SPARK_CORE_SCALE)
	draw_colored_polygon(core, Color.WHITE)


func _reroll_lines() -> void:
	_lines.clear()
	for i: int in _LINE_COUNT:
		# Spread round the circle in even slots with a little slop, so no side
		# of the ship is ever left bare.
		var angle: float = (i + _rng.randf_range(-0.4, 0.4)) * TAU / _LINE_COUNT
		_lines.append([
			angle,
			_rng.randf_range(0.0, _LINE_INNER_JITTER),
			_rng.randf_range(_LINE_MIN_WIDTH, _LINE_MAX_WIDTH),
			_rng.randf() < _ACCENT_SHARE,
		])

	_spark.clear()
	var twist: float = _rng.randf() * TAU
	for i: int in _SPARK_POINTS * 2:
		var radius: float = _rng.randf_range(_SPARK_OUTER_MIN, _SPARK_OUTER_MAX) if i % 2 == 0 else _SPARK_INNER
		_spark.append(Vector2.from_angle(twist + i * PI / _SPARK_POINTS) * radius)


## The lines have closed into the ship by the frame time resumes; only the dim
## lingers, briefly, so the burst that follows lands on a world that's still
## coming back up.
func _release() -> void:
	_released = true
	queue_redraw()
	if not _draws_dim:
		queue_free()
		return
	var tween: Tween = TimeDirector.effect_tween(self)
	tween.tween_method(func(alpha: float) -> void:
		_dim_alpha = alpha
		queue_redraw(), 1.0, 0.0, _DIM_OUT_SECONDS)
	tween.finished.connect(queue_free)
