class_name JumpGate
extends Node2D
## The ring a sector is left through. It isn't there while the gate's boss is
## alive: it warps in once the gatekeeper falls, and stays for as long as the
## player is at the gate. Jumping forward from there flies the ship through it
## (see GameStateManager.go_through_gate and JumpManager.jump_through_gate).
##
## It opens empty and lifeless, then revs up: the portal fills in and its
## spin builds, to a flash and a rain of motes, and settles into the sector
## yellow it's flown through in (see _begin_rev_up()).
##
## Lives behind the cockpit walls, so the ring sits outside the canopy, and its
## passage swallows the window rather than the whole screen. The flash and the
## sector title that follow sit on their own layer above everything.

## Where the ring hangs while it waits, when nothing else is in the way.
@export var rest_position: Vector2 = Vector2(160, 40)
## How far left and right the ring may slide to stay clear of floating salvage.
@export var rest_x_range: Vector2 = Vector2(80, 240)
## How long the warp-in takes, after the beat for the boss's death.
@export var warp_in_time: float = 0.55
## Seconds between the gatekeeper's death and the ring arriving, so the kill
## gets to land first.
@export var arrival_delay: float = 1.1
## How far the ring rushes in at the camera during the passage. At this scale
## its hole is wider than the screen.
@export var passage_scale: float = 9.0
@export var passage_time: float = 1.4

@export_category('Components')
@export var ring: AnimatedSprite2D
## The portal in the sector's yellow: dark while the gate is empty, built up by
## the rev-up.
@export var portal_charged: AnimatedSprite2D
@export var flash: ColorRect
@export var sector_title: Label
@export var sector_subtitle: Label

## The ring's half-width, and the gap it keeps from an offer's tiles.
const _RING_HALF_WIDTH: float = 40.0
const _OFFER_HALF_SPACING: float = 13.0
const _BOB_HEIGHT: float = 2.0
const _BOB_TIME: float = 1.6
## The portal's last pull of light before the rush, and the white-out after it.
const _CHARGE_TIME: float = 0.35
const _WHITE_OUT_TIME: float = 0.08
## Under Reduce Flashing the passage fades to the dark of space instead, and
## more gently: the screen still has to be covered while hyperspace swaps in.
const _REDUCED_FADE_OUT_TIME: float = 0.3
const _REDUCED_FADE_COLOR: Color = Color("#040217")
## Once the boss's salvage is taken the ring slides back to the middle of the
## window, after a beat for the leftover choices to start popping out.
const _RECENTRE_DELAY: float = 0.25
const _RECENTRE_TIME: float = 0.7

## The rev-up. Everything accelerates into the peak: the ring's and the
## portal's spin, the portal's fill and its brightness.
const _REV_UP_TIME: float = 2.4
## A beat after the ring has warped in before the rev-up begins.
const _REV_UP_LEAD: float = 0.15
## How the ring looks lifeless: dim and nearly still.
const _LIFELESS_RING_TINT: Color = Color(0.45, 0.45, 0.5)
const _LIFELESS_RING_SPIN: float = 0.2
const _PEAK_RING_SPIN: float = 3.0
const _LIFELESS_PORTAL_SCALE: float = 0.2
const _LIFELESS_PORTAL_SPIN: float = 0.3
const _PEAK_PORTAL_SPIN: float = 3.0
## Fractions of the rev-up at which a pulse of motes is drawn into the portal.
const _REV_PULSES: Array[float] = [0.3, 0.55, 0.75, 0.9]
const _PEAK_SETTLE_TIME: float = 0.6
## How bright the peak flare is, and how far the screen-wide flash goes.
const _PEAK_BRIGHTNESS: float = 3.0
const _PEAK_SCREEN_FLASH: float = 0.35
const _PEAK_SCREEN_FLASH_TIME: float = 0.5
## Where the rain of motes comes off: the ring's edge.
const _RAIN_SOURCE_RADIUS: float = 34.0
const _RAIN_BURST_COUNT: int = 60
const _RAIN_TRICKLE_COUNT: int = 14
const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")

var _open: bool = false
## True from the moment a passage begins until the next sector starts. The
## passage emits Events.jump like any jump, which would otherwise close the ring.
var _passage_active: bool = false
var _tweens: Array[Tween] = []
## The slide back toward the centre, so a second pick restarts it rather than
## racing it.
var _recentre: Tween
## The peak's burst of falling motes, and the thin trickle that follows it for
## as long as the gate waits.
var _rain_burst: CPUParticles2D
var _rain_trickle: CPUParticles2D


func _ready() -> void:
	Globals.jump_gate = self
	_rain_burst = _make_rain(_RAIN_BURST_COUNT, 1.8, true)
	_rain_trickle = _make_rain(_RAIN_TRICKLE_COUNT, 2.0, false)
	_hide_all()

	Events.start_scenario.connect(_on_start_scenario)
	Events.combat_finished.connect(_on_combat_finished)
	Events.reward_picked.connect(_on_reward_picked)
	Events.jump.connect(func() -> void:
		if not _passage_active:
			close()
	)


## Whether the ring is up and the player can leave the sector through it.
func is_open() -> bool:
	return _open


## Arriving at a gate whose boss is already gone (beaten earlier, or a
## Continue after the win): the ring is waiting. Deferred, because a Continue
## puts the boss's untaken salvage back on this same signal
## (RewardManager._restore_offers), and the ring has to see it to stand aside.
func _on_start_scenario() -> void:
	_open_if_waiting.call_deferred()


func _open_if_waiting() -> void:
	if _passage_active:
		return
	if _at_gate() and not Globals.state_manager.enemy_intents_visible():
		open(true)


## Winning the gate fight is what opens it.
func _on_combat_finished() -> void:
	if not _at_gate() or _open:
		return
	await get_tree().create_timer(arrival_delay).timeout
	# The player may have left in the meantime.
	if _at_gate() and not _open and not _passage_active:
		open(false)


func _at_gate() -> bool:
	var scenario: ScenarioResource = Globals.scenario_manager.current_scenario \
		if Globals.scenario_manager else null
	return scenario != null and scenario.sector_gate_scenario


## Brings the ring in. A quiet arrival skips the warp flash, for a gate that
## was already standing when the player got here.
func open(quiet: bool) -> void:
	_open = true
	_kill_tweens()
	position = Vector2(_clear_rest_x(), rest_position.y)
	modulate = Color.WHITE
	# A warp-in cut short by close() leaves the ring over-bright.
	ring.modulate = Color.WHITE
	ring.show()
	ring.play()

	if quiet:
		ring.scale = Vector2.ONE
	else:
		_warp_in()
	_start_bob()
	_begin_rev_up(0.0 if quiet else warp_in_time + _REV_UP_LEAD)


func _warp_in() -> void:
	ring.scale = Vector2.ONE * 0.15
	ring.modulate = Color(3, 3, 3)
	Juice.ring(self, global_position, Globals.white, 64.0, 0.5, 10.0)
	Juice.ring(self, global_position, Globals.blue, 48.0, 0.6, 6.0)
	Juice.sparkle(self, global_position, Globals.blue, 24, 70.0)
	Events.camera_shake_small.emit()

	var grow: Tween = create_tween().set_parallel()
	grow.tween_property(ring, "scale", Vector2.ONE, warp_in_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(ring, "modulate", Color.WHITE, warp_in_time)
	_tweens.append(grow)


## The gate comes alive. It starts empty: the ring dim and nearly still, the
## portal not there. Over [constant _REV_UP_TIME] (after [param delay]) the
## spin builds and the portal fills with the sector's yellow, pulses of motes
## drawn into it on the way up, then the peak (_rev_peak()).
func _begin_rev_up(delay: float) -> void:
	ring.self_modulate = _LIFELESS_RING_TINT
	ring.speed_scale = _LIFELESS_RING_SPIN
	portal_charged.show()
	portal_charged.play()
	portal_charged.modulate = Color(1, 1, 1, 0)
	portal_charged.scale = Vector2.ONE * _LIFELESS_PORTAL_SCALE
	portal_charged.speed_scale = _LIFELESS_PORTAL_SPIN
	_set_rain(false)

	# Eased in, so it builds slowly and then runs away from itself.
	var rev: Tween = create_tween().set_parallel()\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	rev.tween_property(ring, "speed_scale", _PEAK_RING_SPIN, _REV_UP_TIME).set_delay(delay)
	rev.tween_property(ring, "self_modulate", Color.WHITE, _REV_UP_TIME).set_delay(delay)
	rev.tween_property(portal_charged, "speed_scale", _PEAK_PORTAL_SPIN, _REV_UP_TIME).set_delay(delay)
	rev.tween_property(portal_charged, "modulate:a", 1.0, _REV_UP_TIME).set_delay(delay)
	rev.tween_property(portal_charged, "scale", Vector2.ONE * 0.9, _REV_UP_TIME).set_delay(delay)
	for fraction: float in _REV_PULSES:
		rev.tween_callback(_rev_pulse).set_delay(delay + _REV_UP_TIME * fraction)
	rev.chain().tween_callback(_rev_peak)
	_tweens.append(rev)


## A ring of motes is drawn into the portal.
func _rev_pulse() -> void:
	Juice.gather(self, global_position, Globals.yellow, 6, 34.0, 0.3)


## The top of the rev-up: a flare of light, a shock ring, a flash across the
## screen, and a rain of motes falling away from the ring. The portal settles
## into the steady sector yellow the player jumps through.
func _rev_peak() -> void:
	var glow: float = Juice.soften_flash(_PEAK_BRIGHTNESS - 1.0) + 1.0
	ring.speed_scale = 1.0
	ring.modulate = Color(glow, glow, glow)
	portal_charged.modulate = Color(glow, glow, glow * 0.8)
	portal_charged.scale = Vector2.ONE * 1.2
	var settle: Tween = create_tween().set_parallel()
	settle.tween_property(ring, "modulate", Color.WHITE, _PEAK_SETTLE_TIME)
	settle.tween_property(portal_charged, "modulate", Color.WHITE, _PEAK_SETTLE_TIME)
	settle.tween_property(portal_charged, "scale", Vector2.ONE, _PEAK_SETTLE_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(portal_charged, "speed_scale", 1.0, _PEAK_SETTLE_TIME)
	_tweens.append(settle)

	Juice.ring(self, global_position, Globals.white, 70.0, 0.5, 8.0, 1)
	Juice.ring(self, global_position, Globals.yellow, 54.0, 0.7, 4.0, 1)
	Juice.glint(self, global_position, Globals.white, 22.0, 0.5)
	Events.camera_shake_small.emit()
	_flash_screen()
	_rain_burst.restart()
	_rain_burst.emitting = true
	_rain_trickle.emitting = true


## A pale flash across the whole screen, which fades quickly. Under Reduce
## Flashing it's no more than a faint tint.
func _flash_screen() -> void:
	flash.color = Color(Globals.white, Juice.screen_wash_alpha(_PEAK_SCREEN_FLASH))
	flash.show()
	var fade: Tween = create_tween()
	fade.tween_property(flash, "color:a", 0.0, _PEAK_SCREEN_FLASH_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_callback(flash.hide)
	_tweens.append(fade)


## Yellow motes thrown off the ring's edge: they fall, and drift away from the
## gate as they go. [param burst] is one go off at the peak; otherwise a thin
## stream that keeps on for as long as the gate waits.
func _make_rain(count: int, lifetime: float, burst: bool) -> CPUParticles2D:
	var rain: CPUParticles2D = CPUParticles2D.new()
	rain.texture = _PIXEL_TEXTURE
	rain.amount = count
	rain.lifetime = lifetime
	rain.one_shot = burst
	rain.explosiveness = 0.6 if burst else 0.0
	# In world space, so the motes are left behind when the ring bobs.
	rain.local_coords = false
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	rain.emission_sphere_radius = _RAIN_SOURCE_RADIUS
	rain.direction = Vector2.DOWN
	rain.spread = 40.0
	rain.initial_velocity_min = 8.0
	rain.initial_velocity_max = 30.0
	rain.gravity = Vector2(0.0, 70.0)
	rain.radial_accel_min = 10.0
	rain.radial_accel_max = 30.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 2.0
	rain.color = Globals.yellow
	var fade_out: Gradient = Gradient.new()
	fade_out.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	rain.color_ramp = fade_out
	rain.emitting = false
	add_child(rain)
	return rain


func _set_rain(on: bool) -> void:
	_rain_burst.emitting = on
	_rain_trickle.emitting = on


func _start_bob() -> void:
	var bob: Tween = create_tween().set_loops()\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(self, "position:y", rest_position.y - _BOB_HEIGHT, _BOB_TIME)
	bob.tween_property(self, "position:y", rest_position.y, _BOB_TIME)
	_tweens.append(bob)


## The ring stood aside for the boss's salvage. A pick spends its offer, so
## the ring drifts back to the clearest spot left: the centre of the window
## once nothing remains to dodge. Only its x moves; the bob keeps its y.
func _on_reward_picked() -> void:
	# The pick is announced before its offer marks itself spent, so look for
	# the clear spot once it has.
	_slide_to_clear_spot.call_deferred()


func _slide_to_clear_spot() -> void:
	if not _open or _passage_active:
		return
	var target_x: float = _clear_rest_x()
	if is_equal_approx(target_x, position.x):
		return
	if _recentre and _recentre.is_valid():
		_recentre.kill()
	_recentre = create_tween()
	_recentre.tween_property(self, "position:x", target_x, _RECENTRE_TIME)\
		.set_delay(_RECENTRE_DELAY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(_recentre)


## The x along the window farthest from any salvage still floating there, so
## the boss's reward doesn't sit on top of the portal. The centre when there's
## nothing to avoid, and the spot nearest it when several are equally clear.
## Offers already spent or left behind don't count: they're on their way out.
func _clear_rest_x() -> float:
	var offers: Array[Vector2] = []
	if Globals.reward_manager:
		for child: Node in Globals.reward_manager.get_children():
			if not child is Reward:
				continue
			var reward: Reward = child
			if reward.can_take() or reward.is_on_its_way():
				var half: float = maxf(1, reward.items.size()) * _OFFER_HALF_SPACING
				offers.append(Vector2(reward.global_position.x - half, reward.global_position.x + half))
	if offers.is_empty():
		return rest_position.x

	var best_x: float = rest_position.x
	var best_gap: float = -INF
	var x: float = rest_x_range.x
	while x <= rest_x_range.y:
		var gap: float = INF
		for span: Vector2 in offers:
			# Distance from the ring's edge to the offer's nearest edge.
			gap = minf(gap, maxf(span.x - (x + _RING_HALF_WIDTH), (x - _RING_HALF_WIDTH) - span.y))
		var closer: bool = absf(x - rest_position.x) < absf(best_x - rest_position.x)
		if gap > best_gap + 0.5 or (absf(gap - best_gap) <= 0.5 and closer):
			best_gap = gap
			best_x = x
		x += 5.0
	return best_x


## Takes the ring away without ceremony: the player jumped somewhere else.
func close() -> void:
	_open = false
	_kill_tweens()
	_hide_all()


## Call before the passage's Events.jump, so the ring survives it.
func begin_passage() -> void:
	_passage_active = true


## How long play_passage() runs, from the portal charging to the white frame.
func passage_duration() -> float:
	return _CHARGE_TIME + passage_time + _cover_time()


## The ship flies through: the portal turns gold, the ring rushes at the
## camera until its hole swallows the window, and the screen whites out.
## Returns on the white frame, with the ring gone behind it. The caller swaps
## in hyperspace, then fades the flash with fade_flash().
func play_passage() -> void:
	_kill_tweens()
	ring.speed_scale = 4.0

	_set_rain(false)
	# Already the sector yellow; a gate jumped through mid-rev-up gets its last
	# pull of light here.
	portal_charged.show()
	portal_charged.play()

	var charge: Tween = create_tween().set_parallel()
	charge.tween_property(portal_charged, "modulate", Color.WHITE, _CHARGE_TIME)
	charge.tween_property(portal_charged, "scale", Vector2.ONE, _CHARGE_TIME)
	charge.tween_property(ring, "self_modulate", Color.WHITE, _CHARGE_TIME)
	charge.tween_property(self, "position:y", rest_position.y, _CHARGE_TIME)
	_tweens.append(charge)
	Events.camera_shake_small.emit()
	await charge.finished

	var rush: Tween = create_tween().set_parallel()\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	rush.tween_property(self, "scale", Vector2.ONE * passage_scale, passage_time)
	# Toward the middle of the screen, so the hole is centred as it engulfs it.
	rush.tween_property(self, "position", Globals.SCREEN_SIZE / 2.0, passage_time)
	Globals.background_manager.tween_speed(480, passage_time)
	_tweens.append(rush)
	await rush.finished

	flash.color = Color(_REDUCED_FADE_COLOR if Globals.reduce_flashing else Globals.white, 0.0)
	flash.show()
	var white: Tween = create_tween()
	white.tween_property(flash, "color:a", 1.0, _cover_time())
	_tweens.append(white)
	await white.finished

	Events.camera_shake_large.emit(false)
	_hide_all_but_flash()


## Clears the white-out left by play_passage().
func fade_flash(duration: float) -> void:
	var fade: Tween = create_tween()
	fade.tween_property(flash, "color:a", 0.0, duration)
	fade.tween_callback(flash.hide)


## "SECTOR 2" across hyperspace: where the jump is taking the player.
func show_sector_title(sector_number: int, sector_count: int) -> void:
	sector_title.text = tr("JUMP_GATE_SECTOR").format({"sector": sector_number})
	sector_subtitle.text = tr("JUMP_GATE_OF").format({"total": sector_count})
	for label: Label in [sector_title, sector_subtitle]:
		label.modulate.a = 0.0
		label.show()

	var title: Tween = create_tween()
	title.tween_property(sector_title, "modulate:a", 1.0, 0.35).set_delay(0.25)
	title.parallel().tween_property(sector_subtitle, "modulate:a", 1.0, 0.35).set_delay(0.45)
	title.tween_interval(1.3)
	title.tween_property(sector_title, "modulate:a", 0.0, 0.4)
	title.parallel().tween_property(sector_subtitle, "modulate:a", 0.0, 0.4)
	title.tween_callback(sector_title.hide)
	title.tween_callback(sector_subtitle.hide)


## The next sector has started. Everything goes back to waiting.
func end_passage() -> void:
	_passage_active = false
	close()


func _hide_all() -> void:
	_hide_all_but_flash()
	flash.color.a = 0.0
	flash.hide()
	sector_title.hide()
	sector_subtitle.hide()


func _hide_all_but_flash() -> void:
	_open = false
	scale = Vector2.ONE
	position = rest_position
	ring.hide()
	portal_charged.hide()
	ring.stop()
	portal_charged.stop()
	ring.self_modulate = Color.WHITE
	portal_charged.scale = Vector2.ONE
	portal_charged.speed_scale = 1.0
	_set_rain(false)


## How long the screen takes to be covered at the end of the passage.
func _cover_time() -> float:
	return _REDUCED_FADE_OUT_TIME if Globals.reduce_flashing else _WHITE_OUT_TIME


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween and tween.is_valid():
			tween.kill()
	_tweens.clear()
