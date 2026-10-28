class_name SailTelltales
extends Node2D
## The life on the Outrigger's sail: orange telltales tied along its hem, as a
## sailor ties them to read the wind, and now and then the sun glinting along
## the bolt rope.
##
## The ribbons lean in a steady solar wind and flutter on their own clocks.
## A hit on the hull shakes them; during a jump they stream out flat with the
## background's speed and whip in the buffeting, like the hanging dice.
##
## Positions round to whole sprite pixels, so the ribbons never shimmer
## between pixels at the camera's zoom.

## Where each ribbon is tied, in screen pixels.
@export var anchors: PackedVector2Array
## Pixels in a ribbon, knot included.
@export var ribbon_length: int = 6
## The rope's run, outer end first, for the glint to travel along. The right
## sail mirrors it.
@export var hem: PackedVector2Array
## Seconds between glints (min, max).
@export var glint_gap: Vector2 = Vector2(6.0, 12.0)
@export var glint_time: float = 0.7

const _KNOT: Color = Color("#bd580f")
const _RIBBON: Color = Color("#ee7f2f")
const _TIP: Color = Color("#f29c5d")
const _GLINT: Color = Color("#cef0f1")
const _GLINT_HALO: Color = Color("#eed35d")

## Radians the wind leans a ribbon off straight down, away from the middle.
const _LEAN: float = 0.35
const _FLUTTER: float = 0.28
const _FLUTTER_SPEED: float = 7.0
## A hull hit's extra flutter, and how fast it settles (per second).
const _HIT_FLUTTER: float = 1.1
const _HIT_SETTLE: float = 2.5
## The background's scroll speed at rest and at full hyperspace (see
## HangingDice): between them the ribbons swing up to stream flat.
const _REST_SPEED: float = 16.0
const _CRUISE_SPEED: float = 960.0
const _SCREEN_WIDTH: float = 320.0

var _time: float = 0.0
var _agitation: float = 0.0
var _phases: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _glint_wait: float = 0.0
var _glint_t: float = -1.0
var _glint_right: bool = false


func _ready() -> void:
	_rng.randomize()
	for i: int in anchors.size():
		_phases.append(_rng.randf_range(0.0, TAU))
	_glint_wait = _rng.randf_range(glint_gap.x * 0.3, glint_gap.y)
	Events.player_health_hit.connect(_on_hit)
	Events.player_shields_hit.connect(_on_hit)


func _process(delta: float) -> void:
	# Hitstop freezes the clock; the sail freezes with everything else.
	if delta == 0.0:
		return
	_time += delta
	_agitation = maxf(0.0, _agitation - _HIT_SETTLE * delta)
	_step_glint(delta)
	queue_redraw()


func _on_hit() -> void:
	_agitation = _HIT_FLUTTER


func _step_glint(delta: float) -> void:
	if _glint_t >= 0.0:
		_glint_t += delta / glint_time
		if _glint_t > 1.0:
			_glint_t = -1.0
			_glint_wait = _rng.randf_range(glint_gap.x, glint_gap.y)
		return
	_glint_wait -= delta
	if _glint_wait <= 0.0 and hem.size() > 1:
		_glint_t = 0.0
		_glint_right = _rng.randf() < 0.5


func _draw() -> void:
	var stream: float = _jump_stream()
	for i: int in anchors.size():
		_draw_ribbon(anchors[i], _phases[i], stream)
	if _glint_t >= 0.0:
		_draw_glint()


func _draw_ribbon(anchor: Vector2, phase: float, stream: float) -> void:
	# Away from the middle of the screen, the way the solar wind blows.
	var outward: float = -1.0 if anchor.x < _SCREEN_WIDTH / 2.0 else 1.0
	var at: Vector2 = anchor
	var drawn: Dictionary[Vector2i, bool] = {}
	for i: int in ribbon_length:
		var along: float = float(i) / float(maxi(1, ribbon_length - 1))
		var flutter: float = sin(_time * _FLUTTER_SPEED * (1.0 + _agitation) + phase + i * 0.9)
		var angle: float = PI / 2.0 - outward * (_LEAN + stream * 1.2) * along \
			+ flutter * (_FLUTTER + _agitation * 0.5 + stream * 0.6) * along
		if i > 0:
			at += Vector2.from_angle(angle)
		var pixel: Vector2i = Vector2i(at.round())
		if drawn.has(pixel):
			continue
		drawn[pixel] = true
		var color: Color = _KNOT if i == 0 else (_TIP if i >= ribbon_length - 2 else _RIBBON)
		draw_rect(Rect2(to_local(Vector2(pixel)), Vector2.ONE), color)


## A spark of sunlight runs along the rope from the outer edge inward.
func _draw_glint() -> void:
	var index: int = roundi(_glint_t * (hem.size() - 1))
	for k: int in [-1, 0, 1]:
		var point: Vector2 = hem[clampi(index + k, 0, hem.size() - 1)]
		if _glint_right:
			point.x = _SCREEN_WIDTH - 1.0 - point.x
		draw_rect(Rect2(to_local(point), Vector2.ONE), _GLINT if k == 0 else _GLINT_HALO)


## 0 at cruising speed, 1 at full hyperspace.
func _jump_stream() -> float:
	var background: BackgroundManager = Globals.background_manager
	if background == null or not is_instance_valid(background):
		return 0.0
	return clampf((background.global_speed - _REST_SPEED) / (_CRUISE_SPEED - _REST_SPEED), 0.0, 1.0)
