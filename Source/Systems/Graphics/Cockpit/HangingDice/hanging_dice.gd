class_name HangingDice
extends Node2D
## A pair of gold dice on two chains from one hook in the right canopy strut:
## a nod to the pair in the Millennium Falcon's cockpit.
##
## Each die is a small pendulum that can swing side to side and toward or away
## from the camera, and twist on its chain. Nothing is keyframed. The dice
## react to forces: a lazy drift at idle, a kick when the ship takes a hit,
## and during a jump the background's own speed change, so they lean back
## against the acceleration and flail through the hyperspace buffeting in sync
## with whatever the jump sequence is doing.
##
## Positions are rounded to whole sprite pixels before drawing so the dice and
## chains never shimmer between pixels at the camera's zoom. Swinging toward or
## away from the camera also grows or shrinks a die, rounded to whole pixels
## too, so it stays at its native size through the gentle idle sway and only
## stretches on the big lurches of a jump.

## Twist frames, left to right, covering one full turn on the chain.
@export var sheet: Texture2D
@export var frame_count: int = 12
@export var frame_size: Vector2i = Vector2i(9, 9)
## The hook both chains hang from, in sprite pixels. It sits in the strut's lit
## face rather than on its edge: the edge's dark rim vanishes against space,
## and a chain hung from it looks like it floats.
@export var anchor: Vector2 = Vector2(298, 14)
## One chain per die. Unequal on purpose: the dice hang at different heights,
## and the longer chain swings slower, so the pair never moves as one. Close
## enough that the dice still rest against each other and splay into a V.
@export var chain_lengths: PackedFloat32Array = PackedFloat32Array([14.0, 18.0])

## Pull of "gravity" in sprite pixels per second squared. Sets how fast the
## dice swing: about 1.2 s per swing on the short chain.
const _GRAVITY: float = 300.0
const _SWING_DAMPING: float = 1.1
const _MAX_SWING: float = 1.3
const _TWIST_STIFFNESS: float = 6.0
const _TWIST_DAMPING: float = 1.4
## How far a die slides on screen per pixel it swings toward the camera.
## Coming closer pushes it away from the middle of the view, so the direction
## comes from where the hook sits relative to `_VIEW_CENTRE`.
const _PERSPECTIVE: float = 0.4
## The camera looks at the middle of the walls sprite.
const _VIEW_CENTRE: Vector2 = Vector2(160, 90)
## How far the dice hang from the camera, in sprite pixels. Sets how much they
## grow or shrink with depth: the jump's lean back on the long chain draws them
## about a fifth bigger, and the hard stop's throw forward about a fifth smaller.
const _CAMERA_DISTANCE: float = 60.0

## Idle: a slow, off-beat sway, like a ship that is never perfectly still.
const _IDLE_SWAY: float = 18.0
## Idle: how far the chain's rest twist wanders, in radians.
const _IDLE_TWIST: float = 0.6

## How hard a hit shoves the dice, in sprite pixels per second. Applied as a
## speed rather than an angle so both chains swing about the same distance;
## by angle, the long chain would sweep twice as far.
const _HULL_HIT_KICK: float = 26.0
const _SHIELD_HIT_KICK: float = 12.0
const _HIT_TWIST_KICK: float = 10.0

## Converts the background's speed change (its units per second squared) into
## a push on the dice. Tuned so the full-speed ramp leans them back about 30
## degrees and the hard stop at the end throws them forward about 60.
const _JUMP_ACCEL_SCALE: float = 0.65
const _REST_SPEED: float = 16.0
const _CRUISE_SPEED: float = 960.0
## Random shove at full hyperspace speed, in pixels per second squared.
const _BUFFET: float = 450.0
const _BUFFET_TWIST: float = 60.0

## Room each die needs. Closer than this and they knock together.
const _DIE_WIDTH: float = 7.0
## Stiff enough that two dice resting on each other overlap by under a pixel.
const _CLACK_STIFFNESS: float = 150.0
## Starting lean, so the pair begins already splayed instead of shoving apart
## on the first frame.
const _REST_SPLAY: float = 0.2
## How much closer to the camera, in pixels, the die drawn behind must get
## before it is drawn in front. At rest the two sit at nearly the same depth,
## and swapping on any difference made them pop back and forth while idle.
const _DEPTH_SWAP_MARGIN: float = 1.5

const _MOUNT: Color = Color("#c4c1bc")
const _CHAIN_LIGHT: Color = Color("#8e8b85")
const _CHAIN_DARK: Color = Color("#63605c")


class Die:
	var anchor: Vector2
	var length: float
	## Screen shift per pixel of depth toward the camera.
	var perspective: Vector2
	## x swings side to side, y swings toward (+) or away from the camera.
	var swing: Vector2 = Vector2.ZERO
	var swing_velocity: Vector2 = Vector2.ZERO
	var twist: float = 0.0
	var twist_velocity: float = 0.0
	## Offsets this die's idle drift so the pair never sways in step.
	var phase: float = 0.0
	var buffet: Vector2 = Vector2.ZERO

	func _init(p_anchor: Vector2, p_length: float, p_phase: float, p_perspective: Vector2) -> void:
		anchor = p_anchor
		length = p_length
		phase = p_phase
		twist = p_phase
		perspective = p_perspective

	## Top of the die relative to the hook: x right, y down, z toward the camera.
	func reach() -> Vector3:
		return Vector3(
			sin(swing.x) * cos(swing.y),
			cos(swing.x) * cos(swing.y),
			sin(swing.y)
		) * length

	## Size on screen relative to the sprite, from how close the die has swung.
	func depth_scale() -> float:
		return _CAMERA_DISTANCE / (_CAMERA_DISTANCE - reach().z)

	## Where the top of the die sits on screen, before rounding.
	func hang_point() -> Vector2:
		var offset: Vector3 = reach()
		return anchor + Vector2(offset.x, offset.y) + perspective * offset.z


var _dice: Array[Die] = []
## Back to front. Kept between frames so the order only changes on a clear lead.
var _draw_order: Array[Die] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0

var _last_speed: float = _REST_SPEED
var _has_speed_sample: bool = false
var _speed_accel: float = 0.0


func _ready() -> void:
	_rng.randomize()
	var perspective: Vector2 = (anchor - _VIEW_CENTRE).normalized() * _PERSPECTIVE
	for i: int in range(chain_lengths.size()):
		var die: Die = Die.new(anchor, chain_lengths[i], _rng.randf_range(0.0, TAU), perspective)
		die.swing.x = _REST_SPLAY * (-1.0 if i % 2 == 0 else 1.0)
		_dice.append(die)
	_draw_order = _dice.duplicate()

	Events.player_health_hit.connect(_kick.bind(_HULL_HIT_KICK))
	Events.player_shields_hit.connect(_kick.bind(_SHIELD_HIT_KICK))


func _process(delta: float) -> void:
	# Hitstop freezes time; the dice hang mid-swing with everything else.
	if delta == 0.0:
		return
	# A long frame would let the swing overshoot and blow up.
	delta = minf(delta, 1.0 / 20.0)
	_time += delta

	var forward_push: float = _sample_jump_accel(delta) * _JUMP_ACCEL_SCALE
	var turbulence: float = _jump_turbulence()

	for die: Die in _dice:
		_step_die(die, delta, forward_push, turbulence)
	_knock_together(delta)
	_update_draw_order()

	queue_redraw()


func _draw() -> void:
	if sheet == null:
		return
	for die: Die in _draw_order:
		var top: Vector2i = Vector2i(die.hang_point().round())
		_draw_chain(Vector2i(die.anchor), top)
		_draw_die(die, top)


## A shove from the hull: mostly sideways, a little toward or away from the
## camera, with a spin. Each die gets its own random share so they scatter.
func _kick(strength: float) -> void:
	var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
	for die: Die in _dice:
		die.swing_velocity += Vector2(
			side * _rng.randf_range(0.7, 1.2),
			_rng.randf_range(-0.5, 0.5)
		) * strength / die.length
		die.twist_velocity += _HIT_TWIST_KICK * _rng.randf_range(-1.0, 1.0)


## Rate of change of the background scroll speed. The jump sequence drives
## that speed, so reading it keeps the dice in step with the jump without
## either side knowing about the other's timings.
func _sample_jump_accel(delta: float) -> float:
	var background: BackgroundManager = Globals.background_manager
	if background == null or not is_instance_valid(background):
		_has_speed_sample = false
		return 0.0

	var speed: float = background.global_speed
	if not _has_speed_sample:
		_last_speed = speed
		_has_speed_sample = true
	var raw_accel: float = (speed - _last_speed) / delta
	_last_speed = speed
	# Smoothed so tween steps land as a firm lean rather than a one-frame jolt.
	_speed_accel = lerpf(_speed_accel, raw_accel, 1.0 - exp(-delta * 10.0))
	return _speed_accel


## 0 at normal cruising speed, 1 at full hyperspace.
func _jump_turbulence() -> float:
	if not _has_speed_sample:
		return 0.0
	return clampf((_last_speed - _REST_SPEED) / (_CRUISE_SPEED - _REST_SPEED), 0.0, 1.0)


func _step_die(die: Die, delta: float, forward_push: float, turbulence: float) -> void:
	var idle_push: Vector2 = Vector2(
		sin(_time * 0.8 + die.phase) + 0.6 * sin(_time * 2.1 + die.phase * 1.7),
		0.5 * sin(_time * 0.53 + die.phase * 2.3)
	) * _IDLE_SWAY

	# Buffeting is filtered noise: random enough to read as flailing, smooth
	# enough that the dice still swing rather than teleport.
	var target_buffet: Vector2 = Vector2(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
	) * _BUFFET * turbulence
	die.buffet = die.buffet.lerp(target_buffet, 1.0 - exp(-delta * 8.0))

	var push: Vector2 = idle_push + die.buffet + Vector2(0.0, forward_push)
	var swing_accel: Vector2 = Vector2(
		(-_GRAVITY * sin(die.swing.x) + push.x * cos(die.swing.x)) / die.length,
		(-_GRAVITY * sin(die.swing.y) + push.y * cos(die.swing.y)) / die.length
	) - die.swing_velocity * _SWING_DAMPING
	die.swing_velocity += swing_accel * delta
	die.swing += die.swing_velocity * delta
	die.swing = die.swing.clamp(Vector2(-_MAX_SWING, -_MAX_SWING), Vector2(_MAX_SWING, _MAX_SWING))

	var rest_twist: float = die.phase + _IDLE_TWIST * sin(_time * 0.21 + die.phase)
	var twist_accel: float = -_TWIST_STIFFNESS * (die.twist - rest_twist) \
		- _TWIST_DAMPING * die.twist_velocity \
		+ _rng.randf_range(-1.0, 1.0) * _BUFFET_TWIST * turbulence
	die.twist_velocity += twist_accel * delta
	die.twist += die.twist_velocity * delta


## Swaps neighbours only when the one behind has clearly come closer, so dice
## at about the same depth keep their order instead of flickering.
func _update_draw_order() -> void:
	for i: int in range(_draw_order.size() - 1):
		var behind: Die = _draw_order[i]
		var ahead: Die = _draw_order[i + 1]
		if behind.reach().z - ahead.reach().z > _DEPTH_SWAP_MARGIN:
			_draw_order[i] = ahead
			_draw_order[i + 1] = behind


## Dice sharing a hook bump instead of passing through each other. Only side
## to side, on screen: letting one settle in front of the other is physically
## fine, but at this size the pair then reads as a single lump.
func _knock_together(delta: float) -> void:
	for i: int in range(_dice.size()):
		for j: int in range(i + 1, _dice.size()):
			var a: Die = _dice[i]
			var b: Die = _dice[j]
			var gap: Vector2 = b.hang_point() - a.hang_point()
			if absf(gap.y) >= _DIE_WIDTH or absf(gap.x) >= _DIE_WIDTH:
				continue
			var away: float = 1.0 if gap.x >= 0.0 else -1.0
			var push: float = away * (_DIE_WIDTH - absf(gap.x)) * _CLACK_STIFFNESS * delta
			a.swing_velocity.x -= push / a.length
			b.swing_velocity.x += push / b.length


## One pixel at a time so the chain stays crisp, alternating shades so it
## reads as links rather than a string.
func _draw_chain(from: Vector2i, to: Vector2i) -> void:
	var points: Array[Vector2i] = _line_pixels(from, to)
	for i: int in range(points.size() - 1):
		var color: Color = _CHAIN_LIGHT if i % 2 == 0 else _CHAIN_DARK
		if i == 0:
			color = _MOUNT
		draw_rect(Rect2(Vector2(points[i]), Vector2.ONE), color)


func _draw_die(die: Die, top: Vector2i) -> void:
	var frame: int = posmod(roundi(die.twist / (TAU / frame_count)), frame_count)
	var region: Rect2 = Rect2(Vector2(frame * frame_size.x, 0), Vector2(frame_size))
	# Whole pixels, so small swings round back to the native size and the
	# sprite only stretches once the die has clearly moved in depth.
	var size: Vector2i = Vector2i((Vector2(frame_size) * die.depth_scale()).round())
	# The sheet's first row is empty headroom; the die's top edge is row one.
	var headroom: float = roundf(float(size.y) / frame_size.y)
	var origin: Vector2 = Vector2(top) - Vector2(floorf(size.x / 2.0), headroom)
	draw_texture_rect_region(sheet, Rect2(origin, Vector2(size)), region)


static func _line_pixels(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var delta: Vector2i = (to - from).abs()
	var step: Vector2i = Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var error: int = delta.x - delta.y
	var current: Vector2i = from
	while true:
		points.append(current)
		if current == to:
			break
		var doubled: int = error * 2
		if doubled > -delta.y:
			error -= delta.y
			current.x += step.x
		if doubled < delta.x:
			error += delta.x
			current.y += step.y
	return points
