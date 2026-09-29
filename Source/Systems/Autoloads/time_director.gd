## TimeDirector
## The one owner of Engine.time_scale.
##
## Hitstop and slow-mo both work by slowing the whole game, and they overlap
## constantly — a killing blow wants a hitstop inside a slow-mo. If each one
## set time_scale directly, whichever ended first would restore full speed out
## from under the other. Instead every caller files a request with an end time
## in real (unscaled) milliseconds, and the slowest active request wins.
extends Node

## Time scale during a hitstop. Not zero: a fully stopped clock stalls physics
## interpolation and anything else that divides by delta.
const _HITSTOP_SCALE: float = 0.02

## Active requests as {scale, ends_at_msec}. Pruned as they expire.
var _requests: Array[Dictionary] = []


func _ready() -> void:
	# Must keep ticking while the game is slowed (or paused) to end the slow.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A jump or a scene change should never inherit a half-finished slow-mo.
	Events.jump.connect(clear)
	Events.game_over.connect(clear)


func _process(_delta: float) -> void:
	if _requests.is_empty():
		return
	var now: int = _now_msec()
	_requests = _requests.filter(func(r: Dictionary) -> bool: return r["ends_at_msec"] > now)
	_apply()


## Freezes the game for `duration_ms` of real time, and resolves when it's
## over. Awaited by HitstopEvent, so the effect chain holds on the impact frame.
func hitstop(duration_ms: int) -> void:
	if duration_ms <= 0:
		return
	_add_request(_HITSTOP_SCALE, duration_ms)
	await get_tree().create_timer(duration_ms / 1000.0, true, false, true).timeout


## Slows the game to `time_scale` for `duration_ms` of real time. Doesn't
## block: the point is for whatever comes next to play out slowed.
func slow_mo(time_scale: float, duration_ms: int) -> void:
	if duration_ms <= 0 or time_scale >= 1.0:
		return
	_add_request(clampf(time_scale, _HITSTOP_SCALE, 1.0), duration_ms)


## Drops every request and restores full speed.
func clear() -> void:
	_requests.clear()
	Engine.time_scale = 1.0


func _add_request(time_scale: float, duration_ms: int) -> void:
	_requests.append({
		"scale": time_scale,
		"ends_at_msec": _now_msec() + duration_ms,
	})
	_apply()


## Real time, in ms. A method so tests can step the clock instead of sleeping.
func _now_msec() -> int:
	return Time.get_ticks_msec()


func _apply() -> void:
	var slowest: float = 1.0
	for request: Dictionary in _requests:
		slowest = minf(slowest, request["scale"])
	Engine.time_scale = slowest
