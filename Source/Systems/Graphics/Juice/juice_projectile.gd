class_name JuiceProjectile
extends Node2D
## A shot that isn't a die: a laser beam or a missile, fired from one global
## point at another. Spawned through Juice.projectile(), which draws it on the
## game's pixel grid.
##
## Dice fly at a ship only when that ship keeps them. Anything that hurts a
## ship without handing it the die fires one of these instead, so the player
## never reads a die as given away when it isn't.
##
## While a target node is set, the shot re-aims at it every frame: when another
## ship dies the survivors slide over, and a shot at where the target used to
## be would miss. Frees itself once its impact has faded.

enum Style {
	LASER,   ## A beam that charges at the muzzle, then lashes across at once
	MISSILE, ## A small rocket that lobs out to one side and accelerates in
	## A crackling orb that swells at the muzzle, then drifts in and bursts on
	## the target's shields (Juice.shield_anchor) rather than its middle.
	ION,
}

const _LASER_CHARGE_SECONDS: float = 0.06
const _LASER_DEFAULT_HOLD_SECONDS: float = 0.16
const _LASER_FADE_SECONDS: float = 0.14

const _MISSILE_DEFAULT_FLIGHT_SECONDS: float = 0.45
## How far the lob bows off the straight line, as a share of the distance.
const _MISSILE_BOW_SHARE: float = 0.18
## The most smoke puffs kept behind a missile, oldest first.
const _MISSILE_SMOKE_PUFFS: int = 48
## The missile's body, nose to tail, in game pixels.
const _MISSILE_LENGTH: float = 5.0
const _MISSILE_SMOKE_SECONDS: float = 0.35

const _ION_CHARGE_SECONDS: float = 0.12
const _ION_DEFAULT_FLIGHT_SECONDS: float = 0.38
## How many afterimages trail the orb, and how far apart, as flight progress.
const _ION_TRAIL_STEPS: int = 4
const _ION_TRAIL_SPACING: float = 0.05
## The crackle arcs flung off the orb: how many, and how far they reach.
const _ION_ARCS: int = 2
const _ION_ARC_REACH: float = 5.0

const _IMPACT_SECONDS: float = 0.22

## From the approved palette: the beam's hot core, the missile's flame and
## the smoke it leaves.
const _CORE_COLOR: Color = Color("#cef0f1")
const _FLAME_COLOR: Color = Color("#eed35d")
const _FLAME_TIP_COLOR: Color = Color("#f29c5d")
const _SMOKE_COLOR: Color = Color("#8e8b85")

var style: Style = Style.LASER
var from: Vector2
var to: Vector2
## Optional. While it's valid, its Juice anchor overrides [member to].
var target: Node2D
var color: Color = Color.WHITE
## How long the beam holds (LASER) or the flight takes (MISSILE). Zero or
## less uses the style's default.
var duration: float = 0.0

var _age: float = 0.0
var _bow_side: float = 1.0
## Missile only: where the smoke was shed, and when.
var _smoke: Array[Vector2] = []
var _smoke_ages: PackedFloat32Array = PackedFloat32Array()


## Seconds from launch until the shot lands. Whatever should happen on
## impact (the damage, a hitstop) waits this long.
func impact_seconds() -> float:
	match style:
		Style.MISSILE:
			return _flight_seconds()
		Style.ION:
			return _ION_CHARGE_SECONDS + _flight_seconds()
	return _LASER_CHARGE_SECONDS


func _ready() -> void:
	_bow_side = 1.0 if RNGManager.randf(RNGManager.Bucket.COSMETIC) < 0.5 else -1.0


func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(target) and target.is_inside_tree():
		to = Juice.shield_anchor(target) if style == Style.ION else Juice.anchor_of(target)
	if style == Style.MISSILE:
		_shed_smoke(delta)
	if _age >= _lifetime():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	match style:
		Style.LASER:
			_draw_laser()
		Style.MISSILE:
			_draw_missile()
		Style.ION:
			_draw_ion()
	var since_impact: float = _age - impact_seconds()
	if since_impact >= 0.0 and since_impact < _IMPACT_SECONDS:
		_draw_impact(since_impact / _IMPACT_SECONDS)


func _lifetime() -> float:
	match style:
		Style.MISSILE:
			return _flight_seconds() + maxf(_IMPACT_SECONDS, _MISSILE_SMOKE_SECONDS)
		Style.ION:
			return impact_seconds() + _IMPACT_SECONDS
	return _LASER_CHARGE_SECONDS + _hold_seconds() + _LASER_FADE_SECONDS


func _hold_seconds() -> float:
	return duration if duration > 0.0 else _LASER_DEFAULT_HOLD_SECONDS


func _flight_seconds() -> float:
	if duration > 0.0:
		return duration
	return _ION_DEFAULT_FLIGHT_SECONDS if style == Style.ION else _MISSILE_DEFAULT_FLIGHT_SECONDS


# ── Laser ──────────────────────────────────────────────────────────────────────

func _draw_laser() -> void:
	var start: Vector2 = to_local(from)
	var end: Vector2 = to_local(to)
	if _age < _LASER_CHARGE_SECONDS:
		# A glow swelling at the muzzle, so the beam reads as fired from here.
		var swell: float = _age / _LASER_CHARGE_SECONDS
		draw_circle(start, lerpf(1.0, 3.0, swell), color, true, -1.0, false)
		draw_circle(start, lerpf(0.0, 1.5, swell), _CORE_COLOR, true, -1.0, false)
		return

	var beam_age: float = _age - _LASER_CHARGE_SECONDS
	var fade: float = clampf((beam_age - _hold_seconds()) / _LASER_FADE_SECONDS, 0.0, 1.0)
	var alpha: float = 1.0 - fade
	# Flickers between widths on alternate frames: a steady line reads as a
	# drawn line, a shimmering one as energy.
	var flicker: bool = Engine.get_frames_drawn() % 2 == 0
	var halo: float = lerpf(3.0 if flicker else 4.0, 1.0, fade)
	draw_line(start, end, Color(color, alpha), halo, false)
	if fade < 0.6:
		draw_line(start, end, Color(_CORE_COLOR, alpha), 1.0, false)
	draw_circle(start, lerpf(3.0, 1.0, fade), Color(color, alpha), true, -1.0, false)


# ── Missile ────────────────────────────────────────────────────────────────────

## Where the missile is at [param progress] (0 at launch, 1 on impact). Lobbed
## out to one side along a curve, so a volley doesn't fly as one straight line.
func _missile_point(progress: float) -> Vector2:
	var normal: Vector2 = (to - from).orthogonal().normalized()
	var control: Vector2 = from.lerp(to, 0.35) \
			+ normal * from.distance_to(to) * _MISSILE_BOW_SHARE * _bow_side
	var a: Vector2 = from.lerp(control, progress)
	var b: Vector2 = control.lerp(to, progress)
	return a.lerp(b, progress)


## Accelerates in: slow off the rail, fastest at the target.
func _missile_progress() -> float:
	var t: float = clampf(_age / _flight_seconds(), 0.0, 1.0)
	return t * t * (0.4 + 0.6 * t)


func _shed_smoke(delta: float) -> void:
	for i: int in range(_smoke_ages.size()):
		_smoke_ages[i] += delta
	while not _smoke_ages.is_empty() and _smoke_ages[0] >= _MISSILE_SMOKE_SECONDS:
		_smoke.pop_front()
		_smoke_ages.remove_at(0)
	if _age < _flight_seconds():
		_smoke.append(_missile_point(_missile_progress()))
		_smoke_ages.append(0.0)
		if _smoke.size() > _MISSILE_SMOKE_PUFFS:
			_smoke.pop_front()
			_smoke_ages.remove_at(0)


func _draw_missile() -> void:
	for i: int in range(_smoke.size()):
		var life: float = 1.0 - _smoke_ages[i] / _MISSILE_SMOKE_SECONDS
		var puff: Vector2 = to_local(_smoke[i])
		# Fresh smoke is a fat puff that thins as it fades.
		var size: float = 2.0 if life > 0.5 else 1.0
		draw_rect(Rect2(puff - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(_SMOKE_COLOR, life * 0.8))

	if _age >= _flight_seconds():
		return
	var progress: float = _missile_progress()
	var nose: Vector2 = _missile_point(progress)
	var heading: Vector2 = (nose - _missile_point(maxf(0.0, progress - 0.04))).normalized()
	if heading == Vector2.ZERO:
		heading = (to - from).normalized()
	var side: Vector2 = heading.orthogonal()
	var head: Vector2 = to_local(nose)
	var tail_point: Vector2 = nose - heading * _MISSILE_LENGTH
	var tail: Vector2 = to_local(tail_point)
	# A flame that gutters frame to frame, then fins, the body and a bright nose.
	var flame_length: float = 3.0 if Engine.get_frames_drawn() % 2 == 0 else 5.0
	draw_line(tail, to_local(tail_point - heading * flame_length), _FLAME_TIP_COLOR, 2.0, false)
	draw_line(tail, to_local(tail_point - heading * 2.0), _FLAME_COLOR, 2.0, false)
	draw_line(to_local(tail_point + side * 2.0), to_local(tail_point - side * 2.0), color, 1.0, false)
	draw_line(tail, head, color, 2.0, false)
	draw_rect(Rect2(head - Vector2.ONE, Vector2.ONE * 2.0), _CORE_COLOR)


# ── Ion ────────────────────────────────────────────────────────────────────────

## Where the orb is at [param progress] (0 at the muzzle, 1 on the shields).
## Eases in, so it leaves slowly and lands fast, and sways a pixel or two
## either side of the line so it reads as unstable energy, not a slug.
func _ion_point(progress: float) -> Vector2:
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var sway: Vector2 = (to - from).orthogonal().normalized() \
			* sin(progress * TAU * 1.5) * 1.5 * _bow_side
	return from.lerp(to, eased) + sway * (1.0 - progress)


func _draw_ion() -> void:
	var start: Vector2 = to_local(from)
	if _age < _ION_CHARGE_SECONDS:
		# Gathers at the muzzle before it lets go, like the laser's swell.
		var swell: float = _age / _ION_CHARGE_SECONDS
		draw_circle(start, lerpf(1.0, 4.0, swell), color, true, -1.0, false)
		draw_circle(start, lerpf(0.0, 2.0, swell), _CORE_COLOR, true, -1.0, false)
		_draw_ion_arcs(start, swell)
		return
	var progress: float = (_age - _ION_CHARGE_SECONDS) / _flight_seconds()
	if progress >= 1.0:
		return
	# Afterimages, oldest and faintest first.
	for i: int in range(_ION_TRAIL_STEPS, 0, -1):
		var behind: float = progress - i * _ION_TRAIL_SPACING
		if behind < 0.0:
			continue
		var fade: float = 1.0 - float(i) / (_ION_TRAIL_STEPS + 1)
		draw_circle(to_local(_ion_point(behind)), 1.5 + 1.5 * fade, Color(color, fade * 0.6), true, -1.0, false)
	var at: Vector2 = to_local(_ion_point(progress))
	# Throbs between sizes on alternate frames, like the laser's flicker.
	var pulse: bool = Engine.get_frames_drawn() % 2 == 0
	draw_circle(at, 5.0 if pulse else 4.0, color, true, -1.0, false)
	draw_circle(at, 2.5, _CORE_COLOR, true, -1.0, false)
	_draw_ion_arcs(at, 1.0)


## Short jagged arcs flung off the orb, re-dealt every frame so it crackles.
func _draw_ion_arcs(at: Vector2, strength: float) -> void:
	for i: int in range(_ION_ARCS):
		var direction: Vector2 = Vector2.RIGHT.rotated(RNGManager.randf(RNGManager.Bucket.COSMETIC) * TAU)
		var kink: Vector2 = direction.orthogonal() * (1.5 if i % 2 == 0 else -1.5)
		var reach: float = _ION_ARC_REACH * strength
		var mid: Vector2 = at + direction * reach * 0.55 + kink
		draw_line(at + direction * 2.0, mid, _CORE_COLOR, 1.0, false)
		draw_line(mid, at + direction * reach, color, 1.0, false)


# ── Impact ─────────────────────────────────────────────────────────────────────

## A flare where the shot lands: a bright core and spokes thrown out and
## fading. Missiles hit harder, so theirs is bigger and adds a ring.
func _draw_impact(progress: float) -> void:
	if style == Style.ION:
		_draw_ion_impact(progress)
		return
	var at: Vector2 = to_local(to)
	var big: bool = style == Style.MISSILE
	var alpha: float = 1.0 - progress * progress
	var reach: float = lerpf(2.0, 9.0 if big else 6.0, sqrt(progress))
	var core: float = lerpf(3.0 if big else 2.0, 0.0, progress)
	if core > 0.5:
		draw_circle(at, core, Color(_CORE_COLOR, alpha), true, -1.0, false)
	for i: int in range(8):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * i / 8.0 + 0.4)
		var spoke_color: Color = _FLAME_COLOR if big and i % 2 == 0 else color
		draw_line(at + direction * reach * 0.5, at + direction * reach, Color(spoke_color, alpha), 1.0, false)
	if big:
		draw_arc(at, reach + 1.0, 0.0, TAU, 24, Color(color, alpha * 0.8), 1.0, false)


## The orb bursts against the shields: a ring that spreads and thins, a core
## flash and a last scatter of crackle.
func _draw_ion_impact(progress: float) -> void:
	var at: Vector2 = to_local(to)
	var alpha: float = 1.0 - progress * progress
	var reach: float = lerpf(3.0, 11.0, sqrt(progress))
	draw_arc(at, reach, 0.0, TAU, 24, Color(color, alpha), 2.0 if progress < 0.4 else 1.0, false)
	draw_arc(at, reach * 0.6, 0.0, TAU, 16, Color(_CORE_COLOR, alpha * 0.7), 1.0, false)
	var core: float = lerpf(3.0, 0.0, progress)
	if core > 0.5:
		draw_circle(at, core, Color(_CORE_COLOR, alpha), true, -1.0, false)
	if progress < 0.6:
		_draw_ion_arcs(at, 1.0 + progress * 1.5)
