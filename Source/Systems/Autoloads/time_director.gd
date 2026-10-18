## TimeDirector
## The one owner of Engine.time_scale.
##
## Hitstop and slow-mo both work by slowing the whole game, and they overlap
## constantly — a killing blow wants a hitstop inside a slow-mo. If each one
## set time_scale directly, whichever ended first would restore full speed out
## from under the other. Instead every caller files a request with an end time
## in real (unscaled) milliseconds, and the slowest active request wins.
##
## On top of that sits a base scale (the dev console's `timescale`), which
## every request multiplies against, so effects still read at a slowed speed.
## Request durations stretch with it too, so a hitstop at quarter speed holds
## four times as long.
##
## Effects that must keep moving through a hitstop can't run on game time, and
## shouldn't run on raw real time either, or the base scale couldn't slow them
## down to be judged. They run on effect time: real time at the base speed.
extends Node

## Time scale during a hitstop: a true freeze, so nothing creeps while the
## impact frame holds. Safe only while nothing divides by delta and physics
## interpolation stays off; revisit this if either changes.
const _HITSTOP_SCALE: float = 0.0

## The slowest the base scale stretches durations for, so a base scale near
## zero can't turn a hitstop into a hang.
const _MIN_STRETCH_SCALE: float = 0.01

## The slowest a slow-mo may go. Slow-mo is meant to keep moving; a full stop
## is what hitstop is for.
const _SLOW_MO_FLOOR: float = 0.02

## Active requests as {scale, ends_at_msec}. Pruned as they expire.
var _requests: Array[Dictionary] = []

## The speed the game runs at with no request active. A manual override, so
## clear() leaves it alone: a jump shouldn't undo a speed someone chose.
var base_scale: float = 1.0

## Effect time elapsed since startup, in ms. See effect_msec().
var _effect_msec: float = 0.0
var _last_real_msec: int = -1

## See use_frame_clock().
var _frame_clock: bool = false


func _ready() -> void:
	# Must keep ticking while the game is slowed (or paused) to end the slow.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A jump or a scene change should never inherit a half-finished slow-mo.
	Events.jump.connect(clear)
	Events.game_over.connect(clear)


func _process(_delta: float) -> void:
	var now: int = _now_msec()
	if _last_real_msec >= 0:
		_effect_msec += (now - _last_real_msec) * base_scale
	_last_real_msec = now

	if _requests.is_empty():
		return
	_requests = _requests.filter(func(r: Dictionary) -> bool: return r["ends_at_msec"] > now)
	_apply()


## Freezes the game for `duration_ms` of effect time, and resolves when it's
## over. Awaited by HitstopEvent, so the effect chain holds on the impact frame.
func hitstop(duration_ms: int) -> void:
	if duration_ms <= 0:
		return
	_add_request(_HITSTOP_SCALE, duration_ms)
	await effect_timer(duration_ms / 1000.0).timeout


## Slows the game to `time_scale` for `duration_ms` of effect time. Doesn't
## block: the point is for whatever comes next to play out slowed.
func slow_mo(time_scale: float, duration_ms: int) -> void:
	if duration_ms <= 0 or time_scale >= 1.0:
		return
	_add_request(clampf(time_scale, _SLOW_MO_FLOOR, 1.0), duration_ms)


## Effect time, in ms: it runs straight through hitstops and slow-mos, but at
## the base speed. For effects that time themselves by the clock.
func effect_msec() -> float:
	return _effect_msec


## A tween on [param node] that runs in effect time.
func effect_tween(node: Node) -> Tween:
	return node.create_tween().set_ignore_time_scale(true).set_speed_scale(base_scale)


## A timer that runs out after [param seconds] of effect time.
func effect_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(_stretch(seconds * 1000.0) / 1000.0, true, false, true)


## Sets the speed the game runs at when nothing is slowing it.
func set_base_scale(scale: float) -> void:
	base_scale = maxf(scale, 0.0)
	_apply()


## Drops every request and restores the base speed.
func clear() -> void:
	_requests.clear()
	_apply()


func _add_request(time_scale: float, duration_ms: int) -> void:
	_requests.append({
		"scale": time_scale,
		"ends_at_msec": _now_msec() + roundi(_stretch(duration_ms)),
	})
	_apply()


## How much real time [param msec] of effect time takes.
func _stretch(msec: float) -> float:
	return msec / maxf(base_scale, _MIN_STRETCH_SCALE)


## Real time, in ms. A method so tests can step the clock instead of sleeping.
## On the frame clock it's simulated time instead: see use_frame_clock().
func _now_msec() -> int:
	if _frame_clock:
		return roundi(Engine.get_physics_frames() * 1000.0 / Engine.physics_ticks_per_second)
	return Time.get_ticks_msec()


## Times requests by elapsed frames rather than the wall clock. Under
## `--fixed-fps` a frame no longer takes the time it stands for, so a hitstop
## timed by the wall clock would hold the game frozen for however many
## frames the machine fits into its real duration, and a fast-forwarded run
## would play out differently on a faster machine. Physics frames keep
## ticking through time_scale 0, which a hitstop needs to end.
func use_frame_clock() -> void:
	_frame_clock = true
	_last_real_msec = -1


func _apply() -> void:
	var slowest: float = 1.0
	for request: Dictionary in _requests:
		slowest = minf(slowest, request["scale"])
	Engine.time_scale = base_scale * slowest
