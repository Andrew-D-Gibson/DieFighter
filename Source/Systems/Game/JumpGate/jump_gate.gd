class_name JumpGate
extends Node2D
## The ring a sector is left through. It isn't there while the gate's boss is
## alive: it warps in once the gatekeeper falls, and stays for as long as the
## player is at the gate. Jumping forward from there flies the ship through it
## (see GameStateManager.go_through_gate and JumpManager.jump_through_gate).
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
@export var portal: AnimatedSprite2D
## The portal gone gold as the ship commits to it, faded in over the blue.
@export var portal_charged: AnimatedSprite2D
@export var flash: ColorRect
@export var sector_title: Label
@export var sector_subtitle: Label

## The ring's half-width, and the gap it keeps from an offer's tiles.
const _RING_HALF_WIDTH: float = 40.0
const _OFFER_HALF_SPACING: float = 13.0
const _BOB_HEIGHT: float = 2.0
const _BOB_TIME: float = 1.6
## The portal turning gold before the rush, and the white-out after it.
const _CHARGE_TIME: float = 0.35
const _WHITE_OUT_TIME: float = 0.08

var _open: bool = false
## True from the moment a passage begins until the next sector starts. The
## passage emits Events.jump like any jump, which would otherwise close the ring.
var _passage_active: bool = false
var _tweens: Array[Tween] = []
## Points the player right while the ring is up. See NextSectorPrompt.
var _prompt: NextSectorPrompt


func _ready() -> void:
	Globals.jump_gate = self
	_hide_all()

	Events.start_scenario.connect(_on_start_scenario)
	Events.combat_finished.connect(_on_combat_finished)
	Events.jump.connect(func() -> void:
		if not _passage_active:
			close()
	)


## Whether the ring is up and the player can leave the sector through it.
func is_open() -> bool:
	return _open


## Arriving at a gate whose boss is already gone (beaten earlier, or a
## Continue after the win): the ring is waiting.
func _on_start_scenario() -> void:
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
	portal.show()
	ring.speed_scale = 1.0
	portal.modulate = Color(1, 1, 1, 0)
	ring.play()
	portal.play()

	if quiet:
		ring.scale = Vector2.ONE
		portal.scale = Vector2.ONE
		portal.modulate.a = 1.0
	else:
		_warp_in()
	_start_bob()
	_show_prompt()


func _warp_in() -> void:
	ring.scale = Vector2.ONE * 0.15
	portal.scale = Vector2.ONE * 0.15
	ring.modulate = Color(3, 3, 3)
	Juice.ring(self, global_position, Globals.white, 64.0, 0.5, 10.0)
	Juice.ring(self, global_position, Globals.blue, 48.0, 0.6, 6.0)
	Juice.sparkle(self, global_position, Globals.blue, 24, 70.0)
	Events.camera_shake_small.emit()

	var grow: Tween = create_tween().set_parallel()
	grow.tween_property(ring, "scale", Vector2.ONE, warp_in_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(portal, "scale", Vector2.ONE, warp_in_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(ring, "modulate", Color.WHITE, warp_in_time)
	# The portal lights once the ring has settled, as if powering up.
	grow.tween_property(portal, "modulate:a", 1.0, 0.6).set_delay(warp_in_time)
	_tweens.append(grow)


func _start_bob() -> void:
	var bob: Tween = create_tween().set_loops()\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(self, "position:y", rest_position.y - _BOB_HEIGHT, _BOB_TIME)
	bob.tween_property(self, "position:y", rest_position.y, _BOB_TIME)
	_tweens.append(bob)


## The x along the window farthest from any salvage still floating there, so
## the boss's reward doesn't sit on top of the portal. The centre when there's
## nothing to avoid, and the spot nearest it when several are equally clear.
func _clear_rest_x() -> float:
	var offers: Array[Vector2] = []
	if Globals.reward_manager:
		for child: Node in Globals.reward_manager.get_children():
			if child is Reward and not child.is_queued_for_deletion():
				var reward: Reward = child
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
	_dismiss_prompt()


## Call before the passage's Events.jump, so the ring survives it.
func begin_passage() -> void:
	_passage_active = true
	_dismiss_prompt()


func _show_prompt() -> void:
	_dismiss_prompt()
	_prompt = NextSectorPrompt.new()
	add_child(_prompt)


func _dismiss_prompt() -> void:
	if is_instance_valid(_prompt):
		_prompt.dismiss()
	_prompt = null


## How long play_passage() runs, from the portal charging to the white frame.
func passage_duration() -> float:
	return _CHARGE_TIME + passage_time + _WHITE_OUT_TIME


## The ship flies through: the portal turns gold, the ring rushes at the
## camera until its hole swallows the window, and the screen whites out.
## Returns on the white frame, with the ring gone behind it. The caller swaps
## in hyperspace, then fades the flash with fade_flash().
func play_passage() -> void:
	_kill_tweens()
	ring.speed_scale = 4.0

	portal_charged.modulate.a = 0.0
	portal_charged.show()
	portal_charged.play()

	var charge: Tween = create_tween().set_parallel()
	charge.tween_property(portal_charged, "modulate:a", 1.0, _CHARGE_TIME)
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

	flash.show()
	var white: Tween = create_tween()
	white.tween_property(flash, "color:a", 1.0, _WHITE_OUT_TIME)
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
	sector_title.text = "SECTOR %d" % sector_number
	sector_subtitle.text = "OF %d" % sector_count
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
	portal.hide()
	portal_charged.hide()
	ring.stop()
	portal.stop()
	portal_charged.stop()


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween and tween.is_valid():
			tween.kill()
	_tweens.clear()
