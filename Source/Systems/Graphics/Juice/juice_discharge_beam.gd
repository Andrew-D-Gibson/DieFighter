class_name JuiceDischargeBeam
extends Node2D
## Signature Dragon Ball Z-style shield-drain and energy beam for Discharge
## Plate. Spawned through Juice.discharge_beam() on the game's 320x180 pixel
## grid (JuicePixelated).
##
## Plays in three stages:
##   1. Suck blue shield energy particles out of the player's shield/HP bar on
##      the left side of the screen (both the circular shield ring around the
##      hull gauge and the lower-left shield counter orb);
##   2. Pull and condense that energy at the source tile into a glowing,
##      pulsing, crackling blue energy sphere;
##   3. Blast a massive multi-layered blue energy beam into the targeted enemy
##      ship, timing impact_seconds() to the exact moment the beam head strikes.

const _DRAIN_MOTE_COUNT: int = 28
const _DRAIN_STAGGER_SECONDS: float = 0.26
const _DRAIN_FLIGHT_SECONDS: float = 0.24
const _CHARGE_SECONDS: float = 0.56
const _COMPRESS_SHARE: float = 0.86
const _BEAM_EXTEND_SECONDS: float = 0.10
const _BEAM_HOLD_SECONDS: float = 0.22
const _BEAM_FADE_SECONDS: float = 0.18
const _RECRACKLE_SECONDS: float = 0.035

## Approved palette ramp: white-hot core, bright cyan corona, shield blue body,
## and deep blue rim.
const _CORE_COLOR: Color = Color("#cef0f1")
const _CYAN_COLOR: Color = Color("#8df1f4")
const _BLUE_COLOR: Color = Color("#43a6fc")
const _DEEP_BLUE_COLOR: Color = Color("#2c71aa")

var host_node: Node
var shield_from: Vector2
var hull_from: Vector2
var from: Vector2
var to: Vector2
## Optional. While valid, its Juice anchor updates [member to] every frame.
var target: Node2D
var color: Color = _BLUE_COLOR
## Optional override for time-to-impact; 0 or less uses the default stage timing.
var duration: float = 0.0

var _age: float = 0.0
var _since_crackle: float = 0.0
var _impact_triggered: bool = false
## Each entry: [origin_offset_from_bar, is_hull_ring, delay, flight_dur, bow, size, color_idx]
var _motes: Array[Array] = []
## Jagged electric arcs around the charging sphere (local offsets).
var _sphere_arcs: Array[PackedVector2Array] = []
## Two crackling lightning strands along the beam (t in 0..1, signed offset in px).
var _beam_strands: Array[PackedVector2Array] = []


## Seconds from launch until the beam head slams into the target ship.
## JuiceEvent awaits this so the damage, hitstop, sound and screen shake fire
## on the exact frame of beam impact.
func impact_seconds() -> float:
	if duration > 0.0:
		return duration
	return _CHARGE_SECONDS + _BEAM_EXTEND_SECONDS


func _lifetime() -> float:
	return impact_seconds() + _BEAM_HOLD_SECONDS + _BEAM_FADE_SECONDS


func _ready() -> void:
	_build_drain_motes()
	_reroll_crackle()


func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(target) and target.is_inside_tree():
		to = Juice.anchor_of(target)
	if is_instance_valid(Globals.player) and Globals.player.is_inside_tree():
		shield_from = Globals.player.get_shield_anchor()
		hull_from = Globals.player.get_hull_anchor()
	if not _impact_triggered and _age >= impact_seconds():
		_impact_triggered = true
		_on_beam_impact()
	if _age >= _lifetime():
		queue_free()
		return
	_since_crackle += delta
	if _since_crackle >= _RECRACKLE_SECONDS:
		_since_crackle = 0.0
		_reroll_crackle()
	queue_redraw()


func _draw() -> void:
	var charge_end: float = _charge_duration()
	if _age < charge_end:
		_draw_shield_drain(charge_end)
	_draw_charge_ball(charge_end)
	if _age >= charge_end:
		_draw_beam(charge_end)
	if _age >= impact_seconds():
		_draw_impact()


func _charge_duration() -> float:
	if duration > 0.0:
		return maxf(0.05, duration - _BEAM_EXTEND_SECONDS)
	return _CHARGE_SECONDS


func _build_drain_motes() -> void:
	_motes.clear()
	for i: int in range(_DRAIN_MOTE_COUNT):
		var on_hull_ring: bool = (i % 3) != 0
		var angle: float = TAU * float(i) / float(_DRAIN_MOTE_COUNT) \
				+ RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -0.25, 0.25)
		var radius: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 13.0, 22.0) \
				if on_hull_ring else RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 3.0, 11.0)
		var offset: Vector2 = Vector2.from_angle(angle) * radius
		var delay: float = (float(i) / float(_DRAIN_MOTE_COUNT)) * _DRAIN_STAGGER_SECONDS
		var flight: float = _DRAIN_FLIGHT_SECONDS * RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.85, 1.15)
		var bow: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -20.0, 20.0)
		if absf(bow) < 5.0:
			bow = 8.0 if (i % 2 == 0) else -8.0
		var size: float = 2.0 if (i % 4 != 0) else 3.0
		var color_idx: int = i % 3
		_motes.append([offset, on_hull_ring, delay, flight, bow, size, color_idx])


func _reroll_crackle() -> void:
	_sphere_arcs.clear()
	for i: int in range(4):
		var base_angle: float = TAU * float(i) / 4.0 \
				+ RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -0.5, 0.5)
		var dir: Vector2 = Vector2.from_angle(base_angle)
		var tangent: Vector2 = dir.orthogonal()
		var p0: Vector2 = dir * 3.0
		var p1: Vector2 = dir * 6.5 + tangent * RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -3.5, 3.5)
		var p2: Vector2 = dir * 10.0 + tangent * RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -2.5, 2.5)
		_sphere_arcs.append(PackedVector2Array([p0, p1, p2]))

	_beam_strands.clear()
	for s: int in range(2):
		var pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 8
		var phase: float = RNGManager.randf(RNGManager.Bucket.COSMETIC) * TAU
		var sign_dir: float = 1.0 if s == 0 else -1.0
		for step: int in range(steps + 1):
			var t: float = float(step) / float(steps)
			var wave: float = sin(t * TAU * 1.5 + phase) * 5.5 * sign_dir \
					+ RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -1.5, 1.5)
			if step == 0 or step == steps:
				wave = 0.0
			pts.append(Vector2(t, wave))
		_beam_strands.append(pts)


# ── Stage 1: Shield Drain from Left HUD Bar ───────────────────────────────────

func _draw_shield_drain(charge_end: float) -> void:
	var scale_t: float = _CHARGE_SECONDS / maxf(0.05, charge_end)
	var drain_age: float = _age * scale_t
	var hull_local: Vector2 = to_local(hull_from)
	var shield_local: Vector2 = to_local(shield_from)

	# Collapsing shield rings on the player's HUD gauge as the shield aura shatters
	# and gets sucked out.
	var shatter_t: float = clampf(drain_age / 0.32, 0.0, 1.0)
	if shatter_t < 1.0:
		var ring_alpha: float = (1.0 - shatter_t) * 0.85
		draw_arc(hull_local, lerpf(22.0, 9.0, shatter_t), 0.0, TAU, 28,
				Color(color, ring_alpha), 2.0 if shatter_t < 0.4 else 1.0, false)
		draw_arc(hull_local, lerpf(18.0, 5.0, shatter_t), 0.0, TAU, 24,
				Color(_CYAN_COLOR, ring_alpha * 0.8), 1.0, false)
		draw_arc(shield_local, lerpf(12.0, 3.0, shatter_t), 0.0, TAU, 20,
				Color(_CORE_COLOR, ring_alpha), 1.5, false)

	for mote: Array in _motes:
		var offset: Vector2 = mote[0]
		var on_hull_ring: bool = mote[1]
		var delay: float = mote[2]
		var flight: float = mote[3]
		var bow: float = mote[4]
		var size: float = mote[5]
		var color_idx: int = mote[6]

		var t: float = (drain_age - delay) / flight
		if t <= 0.0 or t >= 1.0:
			continue

		var start_global: Vector2 = (hull_from if on_hull_ring else shield_from) + offset
		var pos_global: Vector2 = _mote_point(start_global, from, t, bow)
		var prev_global: Vector2 = _mote_point(start_global, from, maxf(0.0, t - 0.12), bow)
		var pos_local: Vector2 = to_local(pos_global).round()
		var prev_local: Vector2 = to_local(prev_global).round()

		var mote_color: Color = color
		if color_idx == 0:
			mote_color = _CORE_COLOR
		elif color_idx == 1:
			mote_color = _CYAN_COLOR

		# Motion streak tail + bright particle head that condenses as it enters the sphere.
		var cur_size: float = size if t < 0.8 else 1.0
		draw_line(prev_local, pos_local, Color(mote_color, 0.65), 1.0, false)
		draw_rect(Rect2(pos_local - Vector2.ONE * (cur_size * 0.5), Vector2.ONE * cur_size), mote_color)


func _mote_point(start: Vector2, end: Vector2, t: float, bow: float) -> Vector2:
	# Accelerates out of the shield bar and spirals tightly into the energy ball.
	var eased: float = t * t * (2.2 - 1.2 * t)
	var normal: Vector2 = (end - start).orthogonal().normalized()
	var swirl: float = sin(eased * PI) * (1.0 - 0.4 * eased)
	return start.lerp(end, eased) + normal * (bow * swirl)


# ── Stage 2: Condensing DBZ Energy Ball ───────────────────────────────────────

func _draw_charge_ball(charge_end: float) -> void:
	var center: Vector2 = to_local(from)
	var radius_scale: float = 1.0
	var is_charging: bool = _age < charge_end
	var is_compressing: bool = false

	if is_charging:
		var charge_t: float = clampf(_age / charge_end, 0.0, 1.0)
		if charge_t < _COMPRESS_SHARE:
			radius_scale = ease(charge_t / _COMPRESS_SHARE, 0.55)
		else:
			is_compressing = true
			var compress_t: float = (charge_t - _COMPRESS_SHARE) / (1.0 - _COMPRESS_SHARE)
			radius_scale = lerpf(1.05, 0.72, compress_t)

		# Inward-collapsing DBZ spirit-bomb / kamehameha energy rings & gather lines.
		for r: int in range(2):
			var ring_phase: float = fmod(_age * 4.2 + float(r) * 0.5, 1.0)
			var ring_rad: float = lerpf(18.0, 3.0, ring_phase)
			var ring_alpha: float = sin(ring_phase * PI) * 0.75
			draw_arc(center, ring_rad, 0.0, TAU, 24, Color(_CYAN_COLOR, ring_alpha), 1.0, false)

		for k: int in range(8):
			var streak_phase: float = fmod(_age * 5.0 + float(k) * 0.125, 1.0)
			var angle: float = TAU * float(k) / 8.0 + _age * 2.2
			var dir: Vector2 = Vector2.from_angle(angle)
			var outer_d: float = lerpf(19.0, 4.0, streak_phase)
			var inner_d: float = maxf(2.0, outer_d - 4.5)
			var streak_col: Color = _CORE_COLOR if k % 2 == 0 else _CYAN_COLOR
			draw_line(center + dir * outer_d, center + dir * inner_d,
					Color(streak_col, sin(streak_phase * PI) * 0.85), 1.0, false)
	else:
		var post_impact: float = _age - impact_seconds()
		if post_impact > _BEAM_HOLD_SECONDS:
			var fade_t: float = clampf((post_impact - _BEAM_HOLD_SECONDS) / _BEAM_FADE_SECONDS, 0.0, 1.0)
			radius_scale = 1.0 - fade_t
		else:
			radius_scale = 0.95

	if radius_scale <= 0.02:
		return

	var pulse: float = 0.0
	if not Globals.reduce_flashing:
		pulse = 1.0 if (Engine.get_frames_drawn() % 2 == 0) else -0.6

	var outer_r: float = maxf(2.0, 10.5 * radius_scale + pulse)
	var deep_r: float = maxf(1.5, 8.0 * radius_scale + pulse * 0.5)
	var mid_r: float = maxf(1.2, 6.5 * radius_scale + pulse * 0.5)
	var cyan_r: float = maxf(1.0, 4.5 * radius_scale)
	var core_r: float = maxf(0.8, 2.8 * radius_scale)

	draw_circle(center, outer_r, Color(color, 0.35), true, -1.0, false)
	draw_circle(center, deep_r, Color(_DEEP_BLUE_COLOR, 0.85), true, -1.0, false)
	draw_circle(center, mid_r, color, true, -1.0, false)
	draw_circle(center, cyan_r, _CYAN_COLOR, true, -1.0, false)
	draw_circle(center, core_r, _CORE_COLOR, true, -1.0, false)

	# Crackling electric arcs around the sphere.
	for i: int in range(_sphere_arcs.size()):
		var arc: PackedVector2Array = _sphere_arcs[i]
		var p0: Vector2 = center + arc[0] * radius_scale
		var p1: Vector2 = center + arc[1] * radius_scale
		var p2: Vector2 = center + arc[2] * radius_scale
		draw_line(p0, p1, _CORE_COLOR, 1.0, false)
		draw_line(p1, p2, _CYAN_COLOR if i % 2 == 0 else color, 1.0, false)

	# Bright Kamehameha star-glint on the compression beat right before firing.
	if is_compressing:
		var flash_alpha: float = Juice.soften_flash(0.95)
		draw_line(center + Vector2(-13, 0), center + Vector2(13, 0), Color(_CORE_COLOR, flash_alpha), 1.5, false)
		draw_line(center + Vector2(0, -13), center + Vector2(0, 13), Color(_CORE_COLOR, flash_alpha), 1.5, false)
		draw_line(center + Vector2(-7, -7), center + Vector2(7, 7), Color(_CYAN_COLOR, flash_alpha), 1.0, false)
		draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), Color(_CYAN_COLOR, flash_alpha), 1.0, false)


# ── Stage 3: Massive Blue Energy Beam & Impact ────────────────────────────────

func _draw_beam(charge_end: float) -> void:
	var start: Vector2 = to_local(from)
	var end_full: Vector2 = to_local(to)
	var extend_dur: float = maxf(0.01, impact_seconds() - charge_end)
	var extend_t: float = clampf((_age - charge_end) / extend_dur, 0.0, 1.0)
	var tip: Vector2 = start.lerp(end_full, extend_t)

	var width_scale: float = 1.0
	var alpha: float = 1.0
	var post_impact: float = _age - impact_seconds()
	if post_impact > _BEAM_HOLD_SECONDS:
		var fade_t: float = clampf((post_impact - _BEAM_HOLD_SECONDS) / _BEAM_FADE_SECONDS, 0.0, 1.0)
		width_scale = 1.0 - fade_t * fade_t
		alpha = 1.0 - fade_t
	elif not Globals.reduce_flashing and Engine.get_frames_drawn() % 2 == 0:
		width_scale = 1.14

	if width_scale <= 0.02 or start.is_equal_approx(tip):
		return

	var heading: Vector2 = (tip - start).normalized()
	var normal: Vector2 = heading.orthogonal()

	# Multi-layered DBZ beam shaft: outer glow -> deep blue rim -> shield blue
	# body -> bright cyan inner -> white-hot core.
	draw_line(start, tip, Color(color, 0.38 * alpha), maxf(1.0, 14.0 * width_scale), false)
	draw_line(start, tip, Color(_DEEP_BLUE_COLOR, 0.9 * alpha), maxf(1.0, 10.0 * width_scale), false)
	draw_line(start, tip, Color(color, alpha), maxf(1.0, 7.5 * width_scale), false)
	draw_line(start, tip, Color(_CYAN_COLOR, alpha), maxf(1.0, 4.5 * width_scale), false)
	draw_line(start, tip, Color(_CORE_COLOR, alpha), maxf(1.0, 2.5 * width_scale), false)

	# Surging shock-rings travelling down the beam shaft from source to target.
	for r: int in range(3):
		var surge_t: float = fmod((_age - charge_end) * 5.5 + float(r) * 0.33, 1.0)
		if surge_t <= extend_t:
			var ring_pos: Vector2 = start.lerp(end_full, surge_t)
			var half_w: float = 6.5 * width_scale
			draw_line(ring_pos - normal * half_w, ring_pos + normal * half_w,
					Color(_CORE_COLOR, 0.85 * alpha), 1.5, false)

	# Spiraling electric lightning strands wrapping the beam.
	for s: int in range(_beam_strands.size()):
		var strand: PackedVector2Array = _beam_strands[s]
		var poly: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in strand:
			if pt.x <= extend_t:
				poly.append(start.lerp(end_full, pt.x) + normal * (pt.y * width_scale))
		if poly.size() >= 2:
			var strand_col: Color = _CORE_COLOR if s == 0 else _CYAN_COLOR
			draw_polyline(poly, Color(strand_col, 0.9 * alpha), 1.0, false)

	# Blazing rounded Kamehameha wave-head at the leading tip of the beam.
	draw_circle(tip, 7.0 * width_scale, Color(color, 0.55 * alpha), true, -1.0, false)
	draw_circle(tip, 5.0 * width_scale, Color(_CYAN_COLOR, alpha), true, -1.0, false)
	draw_circle(tip, 3.0 * width_scale, Color(_CORE_COLOR, alpha), true, -1.0, false)


func _on_beam_impact() -> void:
	if is_instance_valid(host_node) and host_node.is_inside_tree():
		Juice.screen_ripple(host_node, to, 0.65)
		Juice.sparkle(host_node, to, _CYAN_COLOR, 14, 55.0)
		Juice.sparkle(host_node, to, _CORE_COLOR, 8, 40.0)


func _draw_impact() -> void:
	var at: Vector2 = to_local(to)
	var post_impact: float = _age - impact_seconds()
	var total_post: float = _BEAM_HOLD_SECONDS + _BEAM_FADE_SECONDS
	var progress: float = clampf(post_impact / total_post, 0.0, 1.0)
	var alpha: float = 1.0 - progress * progress

	var pulse: float = 1.0
	if not Globals.reduce_flashing and Engine.get_frames_drawn() % 2 == 0:
		pulse = 1.15

	var blast_scale: float = (1.0 if post_impact <= _BEAM_HOLD_SECONDS \
			else 1.0 - (post_impact - _BEAM_HOLD_SECONDS) / _BEAM_FADE_SECONDS) * pulse

	if blast_scale > 0.05:
		draw_circle(at, 13.5 * blast_scale, Color(color, 0.42 * alpha), true, -1.0, false)
		draw_circle(at, 9.5 * blast_scale, Color(color, alpha), true, -1.0, false)
		draw_circle(at, 6.5 * blast_scale, Color(_CYAN_COLOR, alpha), true, -1.0, false)
		draw_circle(at, 4.0 * blast_scale, Color(_CORE_COLOR, Juice.soften_flash(alpha)), true, -1.0, false)

	# Expanding shockwave rings around the enemy ship.
	var ring_1: float = lerpf(4.0, 22.0, sqrt(progress))
	var ring_2: float = lerpf(2.0, 14.0, progress)
	draw_arc(at, ring_1, 0.0, TAU, 28, Color(color, alpha * 0.9), 2.0 if progress < 0.35 else 1.0, false)
	draw_arc(at, ring_2, 0.0, TAU, 20, Color(_CORE_COLOR, alpha * 0.8), 1.0, false)

	# Radial high-energy impact rays bursting off the ship.
	var reach: float = lerpf(7.0, 19.0, sqrt(progress))
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0 + 0.35
		var dir: Vector2 = Vector2.from_angle(angle)
		var ray_col: Color = _CORE_COLOR if i % 2 == 0 else _CYAN_COLOR
		draw_line(at + dir * (reach * 0.35), at + dir * reach, Color(ray_col, alpha), 1.5, false)

	# Crackling electric arcs jumping across the impacted ship.
	for i: int in range(_sphere_arcs.size()):
		var arc: PackedVector2Array = _sphere_arcs[i]
		draw_line(at + arc[0] * 1.2, at + arc[1] * 1.3, Color(_CORE_COLOR, alpha), 1.0, false)
		draw_line(at + arc[1] * 1.3, at + arc[2] * 1.4, Color(color, alpha), 1.0, false)
