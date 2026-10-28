class_name SailGauge
extends Node2D
## The Outrigger's engine gauge: a mast standing in the hull gap between its
## two pods, filling from the keel up to the jump gate at the top, with the
## charge spelled out in a badge above it.
##
## While it's the player's turn in a fight, a flickering ghost above the fill
## shows what the dice in hand would add if the turn ended now
## (OutriggerSail.projected_charge()), so the fight-or-flee call is read off
## the mast rather than worked out.
##
## It is the engine's anchor for juice while the systems tab is up: it takes
## the "engine_charger" group from the hidden EngineCharger, and hands back to
## that gauge's anchor while the map (where the charger still shows) is up.

## The fill track, in pixels: x 1..6 of an 8-wide slot, bottom up.
const TRACK_SIZE: Vector2i = Vector2i(8, 72)
const _FILL_LEFT: int = 1
const _FILL_WIDTH: int = 6
const _FILL_HEIGHT: int = 70

const _GHOST_FLICKER_HZ: float = 5.0
const _REDLINE: Color = Color("#d03656")
const _BODY: Color = Color("#c552f1")
const _BODY_LIGHT: Color = Color("#8df1f4")
const _BODY_SHADE: Color = Color("#80359d")
const _BODY_MID: Color = Color("#a846ce")
const _HEAD: Color = Color("#cef0f1")
const _GHOST: Color = Color("#80359d")
const _NOTCH: Color = Color("#463c91")

## The charger the gauge stands in for, whose anchor is used on the map tab.
var charger: Node2D = null
## The readout in the badge above the mast.
var readout: RichTextLabel = null

## The fill as drawn, in charge units, eased towards the real charge.
var _shown_charge: float = 0.0
var _projected: int = 0
var _projecting: bool = false
var _flash: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"engine_charger")
	Events.player_turn_start.connect(_start_projecting)
	Events.first_turn_start.connect(_start_projecting)
	Events.player_turn_over.connect(_stop_projecting)
	Events.combat_finished.connect(_stop_projecting)
	Events.engine_charge_changed.connect(_update_readout)
	Events.start_scenario.connect(_update_readout)
	_update_readout()


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(Globals.player):
		return
	var charge: float = Globals.player.engine_charge
	_shown_charge = move_toward(_shown_charge, charge, maxf(1.0, absf(charge - _shown_charge)) * delta * 8.0)
	_projected = OutriggerSail.projected_charge() if _projecting else Globals.player.engine_charge
	_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()


## Where effects that move engine charge draw to and from: the head of the
## fill on the mast, or the charger's gauge while the map is up.
func get_juice_anchor() -> Vector2:
	if not is_visible_in_tree() and is_instance_valid(charger) and charger.has_method("get_juice_anchor"):
		return charger.get_juice_anchor()
	var head: float = TRACK_SIZE.y - 1 - _fill_pixels(_shown_charge)
	return to_global(Vector2(TRACK_SIZE.x / 2.0, clampf(head, 4.0, TRACK_SIZE.y - 4.0)))


## A die's light reached the mast (SailCatchEvent): flash, and call out what
## it added. The last die of a catch that opened the gate says so.
func catch_light(gain: int, last: bool) -> void:
	_flash = 1.0
	var at: Vector2 = get_juice_anchor()
	Juice.ring(self, at, _BODY, 10.0, 0.3, 2.0)
	Juice.sparkle(self, at, _BODY_LIGHT, 5, 25.0, true)
	Juice.callout_at(self, at + Vector2(10, 0), "+%d" % gain, _BODY)
	if last:
		_celebrate_if_full.call_deferred()


func _celebrate_if_full() -> void:
	# Deferred: the charge event this catch injected resolves just after it.
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(Globals.player) or not Globals.player.is_engine_charged():
		return
	var top: Vector2 = to_global(Vector2(TRACK_SIZE.x / 2.0, 3))
	Juice.ring(self, top, _HEAD, 22.0, 0.5, 3.0)
	Juice.sparkle(self, top, _BODY_LIGHT, 14, 45.0, true)
	if is_instance_valid(readout):
		var pop: Tween = readout.create_tween()
		readout.scale = Vector2(1.4, 1.4)
		pop.tween_property(readout, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.callout_at(self, top + Vector2(0, -14), "SAIL FULL", Globals.white, true)
	Events.camera_shake_small.emit()


func _start_projecting() -> void:
	_projecting = true


func _stop_projecting() -> void:
	_projecting = false


func _update_readout() -> void:
	if not is_instance_valid(readout) or not is_instance_valid(Globals.player):
		return
	var player: Player = Globals.player
	if player.is_overcharged():
		readout.text = "[color=#d03656]%d+%d[/color]" % [player.max_engine_charge, player.overcharge_amount()]
	elif player.is_engine_charged():
		readout.text = "[color=#8df1f4]%d/%d[/color]" % [player.engine_charge, player.max_engine_charge]
	else:
		readout.text = "%d/%d" % [player.engine_charge, player.max_engine_charge]


func _fill_pixels(charge: float) -> int:
	if not is_instance_valid(Globals.player) or Globals.player.max_engine_charge <= 0:
		return 0
	var fraction: float = clampf(charge / Globals.player.max_engine_charge, 0.0, 1.0)
	return roundi(fraction * _FILL_HEIGHT)


func _draw() -> void:
	if not is_instance_valid(Globals.player):
		return
	var bottom: int = TRACK_SIZE.y - 1
	var filled: int = _fill_pixels(_shown_charge)
	var ghost: int = _fill_pixels(_projected)
	var full: bool = Globals.player.is_engine_charged()
	var over: bool = Globals.player.is_overcharged()

	# Notches every quarter of the way, so a part-filled mast can be read.
	for quarter: int in range(1, 4):
		var y: int = bottom - roundi(_FILL_HEIGHT * quarter / 4.0)
		draw_rect(Rect2(0, y, 1, 1), _NOTCH)
		draw_rect(Rect2(TRACK_SIZE.x - 1, y, 1, 1), _NOTCH)

	# The ghost: what ending the turn now would add. Dithered and flickering,
	# so it can't be mistaken for charge already banked.
	if ghost > filled:
		var on: bool = fmod(_time * _GHOST_FLICKER_HZ, 1.0) < 0.75
		for y: int in range(bottom - ghost + 1, bottom - filled + 1):
			for x: int in range(_FILL_LEFT, _FILL_LEFT + _FILL_WIDTH):
				if (x + y) % 2 == 0:
					draw_rect(Rect2(x, y, 1, 1), _GHOST if on else Color(_GHOST, 0.55))
		draw_rect(Rect2(_FILL_LEFT, bottom - ghost + 1, _FILL_WIDTH, 1), Color(_BODY, 0.8 if on else 0.5))

	if filled > 0:
		var top: int = bottom - filled + 1
		var body: Color = _BODY
		if full:
			# A full sail breathes: the go-signal for a jump.
			body = _BODY.lerp(_BODY_LIGHT, 0.25 + 0.25 * sin(_time * 4.0))
		body = body.lerp(_HEAD, _flash * 0.6)
		draw_rect(Rect2(_FILL_LEFT, top, _FILL_WIDTH, filled), body)
		draw_rect(Rect2(_FILL_LEFT, top, 1, filled), _BODY_LIGHT if full else _BODY_MID)
		draw_rect(Rect2(_FILL_LEFT + _FILL_WIDTH - 1, top, 1, filled), _BODY_SHADE)
		# Rungs: the sail's battens, every 6 px, so the fill reads as a sail
		# being raised rather than a bar.
		for y: int in range(bottom - 5, top, -6):
			draw_rect(Rect2(_FILL_LEFT + 1, y, _FILL_WIDTH - 2, 1), Color(_BODY_SHADE, 0.6))
		draw_rect(Rect2(_FILL_LEFT, top, _FILL_WIDTH, 1), _REDLINE if over else _HEAD)
